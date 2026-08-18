#!/usr/bin/env python3
import csv, re, sys, argparse
RANKS = ["d","p","c","o","f","g","s"]

def parse(lineage):
    d={}
    for part in [p.strip() for p in lineage.split(";") if p.strip()]:
        r,name = part.split("__",1)
        d[r[0]] = name
    return d

def join(d):
    return "; ".join(f"{r}__{d.get(r[0],'')}" for r in ["d","p","c","o","f","g","s"])

def genus_from_species(s):
    toks = s.split()
    if len(toks)>=2 and toks[0][0].isupper():
        bad = {"candidatus","uncultured","bacterium","fungus","sp.","sp","cf.","cf"}
        if toks[0].lower() not in bad:
            return toks[0]
    return None

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--in_taxonomy",required=True)
    ap.add_argument("--out_txt",required=True)
    ap.add_argument("--family_lookup_csv")  # 可選：CSV with columns: genus,family
    args=ap.parse_args()

    fam = {}
    if args.family_lookup_csv:
        with open(args.family_lookup_csv,encoding="utf-8") as fh:
            for row in csv.DictReader(fh):
                fam[row["genus"].strip()] = row["family"].strip()

    rows=[]
    with open(args.in_taxonomy,encoding="utf-8") as fh:
        header = fh.readline()
        if "Feature ID" in header and "Taxon" in header:
            rdr = csv.DictReader([header]+fh.readlines(), delimiter="\t")
            rows = [(r["Feature ID"].strip(), r["Taxon"].strip()) for r in rdr]
        else:
            first = header.rstrip("\n").split("\t")
            if len(first)==2: rows.append((first[0], first[1]))
            for line in fh:
                pid, tx = line.rstrip("\n").split("\t",1)
                rows.append((pid, tx))

    out=[]
    for rid, lineage in rows:
        L = parse(lineage)

        # 補 genus
        if (not L.get("g")) and L.get("s"):
            g = genus_from_species(L["s"])
            if g: L["g"] = f"{g}_unclassified"

        # 補 family
        if (not L.get("f")):
            if L.get("g") and L["g"].endswith("_unclassified"):
                g_clean = L["g"][:-13]  # 去掉 _unclassified
                if g_clean in fam:
                    L["f"] = f"{fam[g_clean]}_unclassified"
            if not L.get("f"):
                # 用上一層（order 或更上）名稱佔位
                for up in ["o","c","p","d"]:
                    if L.get(up):
                        L["f"] = f"{L[up]}_unclassified"
                        break

        # 其他缺階（若需要）
        # 例如 o__ 缺，用 c__/p__/d__ 向上找
        for r, chain in [("o",["c","p","d"]), ("c",["p","d"]), ("p",["d"])]:
            if not L.get(r):
                for up in chain:
                    if L.get(up):
                        L[r] = f"{L[up]}_unclassified"
                        break

        out.append((rid, join({k:f"{v}" for k,v in L.items()})))

    with open(args.out_txt,"w",encoding="utf-8") as oh:
        for rid, tx in out:
            oh.write(f"{rid}\t{tx}\n")

if __name__ == "__main__":
    main()
