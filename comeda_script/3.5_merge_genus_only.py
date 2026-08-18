#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
3.5_merge_genus_only.py

Merge genus-only taxa from Kraken2 report into Bracken species report.

This script identifies taxa that are classified only to genus level in Kraken2
but have no corresponding species in Bracken results, and adds them as 
"{Genus_name}_unclassified" species entries.

Author: CoMeDA Development Team
Created: 2025.12
Modified: 2025.12 - Initial version for genus-only taxa recovery
"""

import argparse
import sys
import re
from collections import OrderedDict

# Taxonomy rank codes
RANK_ORDER = ['R', 'R1', 'D', 'K', 'P', 'C', 'O', 'F', 'G', 'S']
RANK_PREFIXES = {
    'D': 'd', 'K': 'k', 'P': 'p', 'C': 'c', 
    'O': 'o', 'F': 'f', 'G': 'g', 'S': 's'
}


class TaxonNode:
    """Represents a taxon node in the taxonomy tree."""
    def __init__(self, percentage, reads_clade, reads_taxon, rank, taxid, name, indent_level):
        self.percentage = percentage
        self.reads_clade = reads_clade
        self.reads_taxon = reads_taxon
        self.rank = rank
        self.taxid = taxid
        self.name = name
        self.indent_level = indent_level
        self.children = []
        self.parent = None
    
    def get_clean_name(self):
        """Get the taxon name without leading/trailing spaces."""
        return self.name.strip()
    
    def to_kreport_line(self):
        """Convert back to kreport format line."""
        # Reconstruct the indented name
        indent = "  " * self.indent_level
        indented_name = indent + self.get_clean_name()
        return f"{self.percentage:6.2f}\t{self.reads_clade}\t{self.reads_taxon}\t{self.rank}\t{self.taxid}\t{indented_name}"


def parse_kreport_line(line):
    """
    Parse a single line from Kraken2/Bracken kreport.
    
    Returns:
        tuple: (percentage, reads_clade, reads_taxon, rank, taxid, name, indent_level)
    """
    parts = line.rstrip('\n').split('\t')
    if len(parts) < 6:
        return None
    
    try:
        percentage = float(parts[0])
        reads_clade = int(parts[1])
        reads_taxon = int(parts[2])
        rank = parts[3]
        taxid = parts[4]
        name = parts[5]
        
        # Calculate indent level from leading spaces in name
        stripped_name = name.lstrip()
        indent_level = (len(name) - len(stripped_name)) // 2
        
        return (percentage, reads_clade, reads_taxon, rank, taxid, name, indent_level)
    except (ValueError, IndexError):
        return None


def parse_kreport(filepath):
    """
    Parse a Kraken2/Bracken kreport file into a list of TaxonNode objects.
    
    Args:
        filepath: Path to the kreport file
        
    Returns:
        list: List of TaxonNode objects in original order
    """
    nodes = []
    
    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            parsed = parse_kreport_line(line)
            if parsed is None:
                continue
            
            percentage, reads_clade, reads_taxon, rank, taxid, name, indent_level = parsed
            node = TaxonNode(percentage, reads_clade, reads_taxon, rank, taxid, name, indent_level)
            nodes.append(node)
    
    return nodes


def build_taxonomy_tree(nodes):
    """
    Build parent-child relationships from parsed nodes.
    
    Args:
        nodes: List of TaxonNode objects
        
    Returns:
        list: Same list with parent/children relationships set
    """
    stack = []  # Stack to track parent nodes at each indent level
    
    for node in nodes:
        # Pop nodes from stack that are at same or deeper level
        while stack and stack[-1].indent_level >= node.indent_level:
            stack.pop()
        
        # Set parent relationship
        if stack:
            node.parent = stack[-1]
            stack[-1].children.append(node)
        
        # Push current node to stack
        stack.append(node)
    
    return nodes


def extract_genus_from_species_name(species_name):
    """
    Extract genus name from species name.
    
    Args:
        species_name: Full species name (e.g., "Bacteroides fragilis")
        
    Returns:
        str: Genus name or None if cannot extract
    """
    clean_name = species_name.strip()
    
    # Skip special cases
    skip_prefixes = ['uncultured', 'unidentified', 'bacterium', 'fungus', 
                     'candidatus', 'unclassified']
    for prefix in skip_prefixes:
        if clean_name.lower().startswith(prefix):
            return None
    
    # Split by space and take first word
    parts = clean_name.split()
    if len(parts) >= 1:
        genus = parts[0]
        # Validate: genus should start with uppercase
        if genus[0].isupper() and len(genus) > 1:
            return genus
    
    return None


def find_genus_only_taxa(kraken2_nodes, bracken_nodes):
    """
    Find genera that have reads in Kraken2 but no corresponding species in Bracken.
    
    Args:
        kraken2_nodes: List of TaxonNode from Kraken2 kreport
        bracken_nodes: List of TaxonNode from Bracken kreport
        
    Returns:
        list: List of TaxonNode representing genus-only taxa
    """
    # Step 1: Extract all genera that have species in Bracken
    genera_with_species = set()
    
    for node in bracken_nodes:
        if node.rank == 'S' and node.reads_taxon > 0:
            genus = extract_genus_from_species_name(node.get_clean_name())
            if genus:
                genera_with_species.add(genus)
    
    # Step 2: Find genera in Kraken2 that have reads but no species in Bracken
    genus_only_taxa = []
    
    for node in kraken2_nodes:
        if node.rank == 'G' and node.reads_taxon > 0:
            genus_name = node.get_clean_name()
            
            # Check if this genus has species in Bracken
            if genus_name not in genera_with_species:
                genus_only_taxa.append(node)
    
    return genus_only_taxa


def get_ancestry_chain(node):
    """
    Get the full ancestry chain from root to the given node.
    
    Args:
        node: A TaxonNode
        
    Returns:
        list: List of TaxonNode from root to node (inclusive)
    """
    chain = []
    current = node
    while current:
        chain.append(current)
        current = current.parent
    chain.reverse()
    return chain


def find_insertion_point_and_hierarchy(bracken_nodes, genus_node, kraken2_nodes):
    """
    Find the correct position to insert a genus-only taxon in Bracken kreport,
    and determine what hierarchy needs to be added.
    
    Strategy:
    1. If the genus exists in Bracken kreport, insert species after it
    2. If not, find the deepest existing ancestor and copy hierarchy from there
    3. If no ancestor found, append full hierarchy at end of Bacteria/Fungi section
    
    Args:
        bracken_nodes: List of TaxonNode from Bracken kreport
        genus_node: The genus-only TaxonNode to insert
        kraken2_nodes: List of TaxonNode from Kraken2 kreport (for parent lookup)
        
    Returns:
        tuple: (insert_index, hierarchy_to_add, bracken_genus_node_or_none)
               hierarchy_to_add is a list of TaxonNode to insert (may include parents + genus + species)
    """
    genus_name = genus_node.get_clean_name()
    
    # First, check if genus exists in Bracken kreport
    for i, node in enumerate(bracken_nodes):
        if node.rank == 'G' and node.get_clean_name() == genus_name:
            # Found the genus, insert species after it
            insert_idx = i + 1
            while insert_idx < len(bracken_nodes):
                if bracken_nodes[insert_idx].indent_level <= node.indent_level:
                    break
                insert_idx += 1
            return (insert_idx, [], node)
    
    # Genus not in Bracken kreport
    # Get full ancestry from Kraken2
    ancestry = get_ancestry_chain(genus_node)
    
    # Find the deepest ancestor that exists in Bracken
    deepest_match_idx = -1
    deepest_match_level = -1
    bracken_match_node = None
    
    for ancestor in ancestry:
        if ancestor.rank in ['U', 'R']:  # Skip unclassified and root
            continue
        
        ancestor_name = ancestor.get_clean_name()
        
        for i, bnode in enumerate(bracken_nodes):
            if bnode.rank == ancestor.rank and bnode.get_clean_name() == ancestor_name:
                if ancestor.indent_level > deepest_match_level:
                    deepest_match_idx = i
                    deepest_match_level = ancestor.indent_level
                    bracken_match_node = bnode
                break
    
    # Build hierarchy to add (from after deepest match to genus)
    hierarchy_to_add = []
    
    if bracken_match_node:
        # Found an ancestor, add nodes from after that ancestor to genus
        found_ancestor = False
        base_indent = bracken_match_node.indent_level
        
        for ancestor in ancestry:
            if ancestor.rank == bracken_match_node.rank and ancestor.get_clean_name() == bracken_match_node.get_clean_name():
                found_ancestor = True
                continue
            
            if found_ancestor and ancestor.rank not in ['U', 'R', 'R1']:
                # Clone this node with adjusted indent
                new_node = TaxonNode(
                    percentage=ancestor.percentage,
                    reads_clade=ancestor.reads_clade,
                    reads_taxon=ancestor.reads_taxon,
                    rank=ancestor.rank,
                    taxid=ancestor.taxid,
                    name=ancestor.get_clean_name(),
                    indent_level=base_indent + len(hierarchy_to_add) + 1
                )
                hierarchy_to_add.append(new_node)
        
        # Find insertion point (after deepest match's subtree)
        insert_idx = deepest_match_idx + 1
        while insert_idx < len(bracken_nodes):
            if bracken_nodes[insert_idx].indent_level <= bracken_match_node.indent_level:
                break
            insert_idx += 1
        
        return (insert_idx, hierarchy_to_add, None)
    
    else:
        # No ancestor found in Bracken, need to add full hierarchy
        # Find the domain (Bacteria/Fungi) in Bracken to insert after
        domain_idx = -1
        domain_node = None
        
        for i, bnode in enumerate(bracken_nodes):
            if bnode.rank == 'D':
                domain_idx = i
                domain_node = bnode
        
        if domain_node:
            base_indent = domain_node.indent_level
            
            # Add all nodes from phylum to genus
            for ancestor in ancestry:
                if ancestor.rank in ['U', 'R', 'R1', 'D', 'K']:
                    continue
                
                new_node = TaxonNode(
                    percentage=ancestor.percentage,
                    reads_clade=ancestor.reads_clade,
                    reads_taxon=ancestor.reads_taxon,
                    rank=ancestor.rank,
                    taxid=ancestor.taxid,
                    name=ancestor.get_clean_name(),
                    indent_level=base_indent + len(hierarchy_to_add) + 1
                )
                hierarchy_to_add.append(new_node)
            
            # Insert at end of file
            return (len(bracken_nodes), hierarchy_to_add, None)
        
        else:
            # Fallback: just add genus at end
            hierarchy_to_add.append(TaxonNode(
                percentage=genus_node.percentage,
                reads_clade=genus_node.reads_clade,
                reads_taxon=genus_node.reads_taxon,
                rank='G',
                taxid=genus_node.taxid,
                name=genus_node.get_clean_name(),
                indent_level=genus_node.indent_level
            ))
            return (len(bracken_nodes), hierarchy_to_add, None)


def create_unclassified_species_node(genus_node, bracken_genus_node=None):
    """
    Create a new species node for genus-only taxon.
    
    Args:
        genus_node: The genus TaxonNode from Kraken2
        bracken_genus_node: The genus TaxonNode from Bracken (if exists)
        
    Returns:
        TaxonNode: New species node representing unclassified species
    """
    # Use Bracken genus node if available (has updated reads), otherwise use Kraken2 genus
    source_node = bracken_genus_node if bracken_genus_node else genus_node
    
    genus_name = genus_node.get_clean_name()
    species_name = f"{genus_name}_unclassified"
    
    # Create new species node
    # reads_taxon for genus becomes reads for the unclassified species
    new_node = TaxonNode(
        percentage=source_node.percentage,
        reads_clade=source_node.reads_taxon,  # Use reads_taxon from genus
        reads_taxon=source_node.reads_taxon,
        rank='S',
        taxid=source_node.taxid,  # Use same taxid as genus
        name=species_name,
        indent_level=source_node.indent_level + 1
    )
    
    return new_node


def merge_genus_only_taxa(bracken_nodes, genus_only_taxa, kraken2_nodes):
    """
    Merge genus-only taxa into Bracken kreport.
    
    Args:
        bracken_nodes: List of TaxonNode from Bracken kreport
        genus_only_taxa: List of genus-only TaxonNode from Kraken2
        kraken2_nodes: Full list of Kraken2 nodes (for parent lookup)
        
    Returns:
        list: Merged list of TaxonNode
    """
    # 2026-07-30 穩健改寫：不再用 find_insertion_point_and_hierarchy 的「位置插入」法
    # （會因 kreport2mpa 依縮排+行順序重建 lineage，而把 genus 掛到前一個科，如 Desulfovibrionaceae，
    #  造成科屬不符、且正確 genus 被蓋掉）。改為對每個 genus-only taxon，用它在 Kraken2 樹上的正確
    # ancestry 產生一段「自足」的 lineage 區塊附在檔尾：從淺(Bacteria)到深(genus)，縮排自洽，
    # kreport2mpa 的堆疊遇淺縮排會歸位，故必重建出正確 lineage，與 Bracken 既有結構無關。
    build_taxonomy_tree(kraken2_nodes)
    result = list(bracken_nodes)

    for genus_node in genus_only_taxa:
        ancestry = get_ancestry_chain(genus_node)  # [root, D, P, C, O, F, G]（含 genus 本身）
        # 附上完整 ancestry（每個祖先一行，用其在 Kraken2 的原始縮排；內部節點 reads 照抄，
        # 於 4.1 只取 species(NF==7) 時會被濾掉，不影響最終 species 表，也不會錯掛）
        for anc in ancestry:
            if anc.rank in ('U', 'R', 'R1'):
                continue
            result.append(TaxonNode(
                percentage=anc.percentage,
                reads_clade=anc.reads_clade,
                reads_taxon=anc.reads_taxon,
                rank=anc.rank,
                taxid=anc.taxid,
                name=anc.get_clean_name(),
                indent_level=anc.indent_level,
            ))
        # 未定種 species（{genus}_unclassified）承接該屬的 reads_taxon
        result.append(TaxonNode(
            percentage=genus_node.percentage,
            reads_clade=genus_node.reads_taxon,
            reads_taxon=genus_node.reads_taxon,
            rank='S',
            taxid=genus_node.taxid,
            name=f"{genus_node.get_clean_name()}_unclassified",
            indent_level=genus_node.indent_level + 1,
        ))

    return result


def write_kreport(nodes, output_path):
    """
    Write merged nodes to kreport file.
    
    Args:
        nodes: List of TaxonNode
        output_path: Output file path
    """
    with open(output_path, 'w', encoding='utf-8') as f:
        for node in nodes:
            line = node.to_kreport_line()
            f.write(line + '\n')


def main():
    parser = argparse.ArgumentParser(
        description='Merge genus-only taxa from Kraken2 into Bracken species report',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Example usage:
    python 3.5_merge_genus_only.py \\
        --bracken sample.taxa.kraken2_bracken_species.txt \\
        --kraken2 sample.taxa.kraken2.txt \\
        --output sample.taxa.merged.txt

This script identifies genera that have reads in Kraken2 but no corresponding 
species in Bracken results, and adds them as "{Genus}_unclassified" entries.
        '''
    )
    
    parser.add_argument('--bracken', '-b', required=True,
                        help='Bracken species kreport file (*.taxa.kraken2_bracken_species.txt)')
    parser.add_argument('--kraken2', '-k', required=True,
                        help='Kraken2 kreport file (*.taxa.kraken2.txt)')
    parser.add_argument('--output', '-o', required=True,
                        help='Output merged kreport file')
    parser.add_argument('--min-reads', '-m', type=int, default=1,
                        help='Minimum reads_taxon for genus to be included (default: 1)')
    parser.add_argument('--verbose', '-v', action='store_true',
                        help='Print verbose output')
    
    args = parser.parse_args()
    
    # Parse input files
    if args.verbose:
        print(f"[INFO] Reading Bracken kreport: {args.bracken}", file=sys.stderr)
    bracken_nodes = parse_kreport(args.bracken)
    
    if args.verbose:
        print(f"[INFO] Reading Kraken2 kreport: {args.kraken2}", file=sys.stderr)
    kraken2_nodes = parse_kreport(args.kraken2)
    
    # Build taxonomy tree for Kraken2 (for parent lookups)
    build_taxonomy_tree(kraken2_nodes)
    
    # Find genus-only taxa
    genus_only_taxa = find_genus_only_taxa(kraken2_nodes, bracken_nodes)
    
    # Filter by minimum reads
    genus_only_taxa = [g for g in genus_only_taxa if g.reads_taxon >= args.min_reads]
    
    if args.verbose:
        print(f"[INFO] Found {len(genus_only_taxa)} genus-only taxa", file=sys.stderr)
        for g in genus_only_taxa:
            print(f"       - {g.get_clean_name()} (reads: {g.reads_taxon})", file=sys.stderr)
    
    # Merge
    if len(genus_only_taxa) > 0:
        merged_nodes = merge_genus_only_taxa(bracken_nodes, genus_only_taxa, kraken2_nodes)
        
        if args.verbose:
            print(f"[INFO] Merged {len(genus_only_taxa)} genus-only taxa", file=sys.stderr)
    else:
        merged_nodes = bracken_nodes
        if args.verbose:
            print("[INFO] No genus-only taxa to merge", file=sys.stderr)
    
    # Write output
    write_kreport(merged_nodes, args.output)
    
    if args.verbose:
        print(f"[INFO] Output written to: {args.output}", file=sys.stderr)
    
    # Print summary
    print(f"[MERGE SUMMARY] Bracken species: {len([n for n in bracken_nodes if n.rank == 'S'])}, "
          f"Genus-only added: {len(genus_only_taxa)}, "
          f"Total species: {len([n for n in merged_nodes if n.rank == 'S'])}")


if __name__ == '__main__':
    main()
