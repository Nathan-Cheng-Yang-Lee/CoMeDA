# fastCCLasso for precomputed CLR data
#
# This adaptation changes only the input/preprocessing boundary of the original
# fastCCLasso implementation (Zhang, Fang, and Hu; source dated 2024-01-11).
# The original function computes
#   xx2 <- log(xx) - rowMeans(log(xx))
# from compositional proportions. Here, xx2 is supplied directly as CoMeDA CLR
# values. Lambda selection, sample-wise cross-validation, estimation,
# bootstrap resampling, and the original p-value calculation are unchanged.

fastCCLasso_CLR <- function(clr_data, k_cv = 3,
                            lam_min_ratio = 1E-4, k_max = 20,
                            n_boot = 100, aa = NULL, bb = NULL) {
  xx2 <- as.matrix(clr_data)
  n <- nrow(xx2)
  p <- ncol(xx2)

  if (!is.numeric(xx2) || n < 3L || p < 2L || any(!is.finite(xx2))) {
    stop("clr_data must be a finite numeric matrix with at least 3 rows and 2 columns.")
  }
  if (k_cv < 2L || k_cv > n) {
    stop("k_cv must be between 2 and the number of samples.")
  }
  if (n_boot < 1L) {
    stop("n_boot must be at least 1.")
  }

  vxx2 <- stats::var(xx2)

  if (is.null(aa)) {
    aa <- rep(1, p)
  }
  if (is.null(bb)) {
    bb <- 1 / diag(vxx2)
  }

  # Golden-section selection of lambda on the log10 scale.
  xx <- vxx2 * (aa * rep(bb, each = p) + bb * rep(aa, each = p)) / 2
  diag(xx) <- 0
  lam_max <- max(abs(xx))
  lam_int2 <- log10(lam_max * c(lam_min_ratio, 1))
  a1 <- lam_int2[1]
  b1 <- lam_int2[2]

  lams <- NULL
  fvals <- NULL
  a2 <- a1 + 0.382 * (b1 - a1)
  b2 <- a1 + 0.618 * (b1 - a1)
  fb2 <- cvfastCCLasso_CLR(lambda = 10^b2, k_cv = k_cv, xx2 = xx2,
                           aa = aa, bb = bb)
  lams <- c(lams, b2)
  fvals <- c(fvals, fb2)
  fa2 <- cvfastCCLasso_CLR(lambda = 10^a2, k_cv = k_cv, xx2 = xx2,
                           aa = aa, bb = bb)
  lams <- c(lams, a2)
  fvals <- c(fvals, fa2)

  err_lam2 <- 1e-1 * max(1, lam_int2)
  err_fval <- 1e-4
  err <- b1 - a1
  k <- 0

  while (err > err_lam2 && k < k_max) {
    fval_max <- max(fa2, fb2)
    if (fa2 > fb2) {
      a1 <- a2
      a2 <- b2
      fa2 <- fb2
      b2 <- a1 + 0.618 * (b1 - a1)
      fb2 <- cvfastCCLasso_CLR(lambda = 10^b2, k_cv = k_cv, xx2 = xx2,
                               aa = aa, bb = bb)
      lams <- c(lams, b2)
      fvals <- c(fvals, fb2)
    } else {
      b1 <- b2
      b2 <- a2
      fb2 <- fa2
      a2 <- a1 + 0.382 * (b1 - a1)
      fa2 <- cvfastCCLasso_CLR(lambda = 10^a2, k_cv = k_cv, xx2 = xx2,
                               aa = aa, bb = bb)
      lams <- c(lams, a2)
      fvals <- c(fvals, fa2)
    }
    fval_min <- min(fa2, fb2)
    k <- k + 1
    err <- b1 - a1
    if (abs(fval_max - fval_min) / (1 + fval_min) <= err_fval) {
      break
    }
  }

  info_cv <- list(lams = lams, fvals = fvals, k = k + 2,
                  lam_int = 10^c(a1, b1))
  lambda <- 10^((a2 + b2) / 2)
  fit_res <- fastcclasso_sub_CLR(lambda = lambda, SS2 = vxx2,
                                 aa = aa, bb = bb)

  sigma_mod <- boot_fastCCLasso_CLR(
    xx2 = xx2, sigma_hat = fit_res$sigma, lambda = lambda,
    aa = aa, bb = bb, n_boot = n_boot, max_iter = 200,
    stop_eps = 1e-6
  )

  # CoMeDA-facing names preserve compatibility with existing network scripts.
  list(
    correlation_matrix = sigma_mod$cor_w,
    variance_diagonal = sigma_mod$var_w,
    optimal_lambda = lambda,
    cv_info = info_cv,
    p_values = sigma_mod$p_vals
  )
}

# Cross-validation loss for one lambda. Folds are consecutive sample blocks,
# matching the original fastCCLasso implementation.
cvfastCCLasso_CLR <- function(lambda, k_cv, xx2, aa, bb) {
  n <- nrow(xx2)
  p <- ncol(xx2)
  n_b <- floor(n / k_cv)
  cv.loss <- 0
  for (k in 1:k_cv) {
    ite <- (n_b * (k - 1) + 1):(n_b * k)
    vxx2te <- stats::var(xx2[ite, ])
    vxx2tr <- stats::var(xx2[-ite, ])
    out <- fastcclasso_sub_CLR(lambda = lambda, SS2 = vxx2tr,
                               aa = aa, bb = bb)
    mm <- out$sigma - out$ww - rep(out$ww, each = p) - vxx2te
    cv.loss <- cv.loss + mean(mm^2 * aa * rep(bb, each = p))
  }
  cv.loss
}

# fastCCLasso estimator for one lambda.
fastcclasso_sub_CLR <- function(lambda, SS2, aa, bb,
                                k_max = 200, x_tol = 1E-4) {
  p <- ncol(SS2)
  cc <- 1 / (aa * sum(bb) + bb * sum(aa))
  aa2 <- aa * cc
  bb2 <- bb * cc
  cab1 <- 1 + sum(aa * bb2)
  caa <- sum(aa * aa2)
  cbb <- sum(bb * bb2)
  aabb <- aa * rep(bb, each = p) + bb * rep(aa, each = p)
  lambda2 <- 2 * lambda / aabb
  ss2 <- rowSums(SS2 * aabb)
  sigma <- SS2
  ww <- colMeans(sigma) - mean(sigma) / 2
  k <- 0
  err <- 1
  while (err > x_tol && k < k_max) {
    xx <- rowSums(sigma * aabb) - ss2
    ax1 <- sum(aa2 * xx)
    bx1 <- sum(bb2 * xx)
    ww2 <- xx * cc +
      (aa2 * (cbb * ax1 - cab1 * bx1) +
         bb2 * (caa * bx1 - cab1 * ax1)) /
      (cab1^2 - caa * cbb)

    sigma2 <- SS2 + ww2 + rep(ww2, each = p)
    oo <- diag(sigma2)
    sigma2 <- (sigma2 > lambda2) * (sigma2 - lambda2) +
      (sigma2 < -lambda2) * (sigma2 + lambda2)
    diag(sigma2) <- oo

    err <- max(abs(sigma2 - sigma) / (abs(sigma) + 1))
    k <- k + 1
    sigma <- sigma2
  }
  list(sigma = sigma, ww = ww2)
}

# Bootstrap and p-value calculation copied method-for-method from the original.
boot_fastCCLasso_CLR <- function(xx2, sigma_hat, lambda, aa, bb,
                                 n_boot = 100, max_iter = 200,
                                 stop_eps = 1e-6) {
  n <- nrow(xx2)
  p <- ncol(xx2)

  cors_boot <- matrix(0, nrow = p * (p - 1) / 2, ncol = n_boot + 1)
  vars_boot <- matrix(0, nrow = p, ncol = n_boot + 1)
  cors_mat <- matrix(0, p, p)
  ind_low <- lower.tri(cors_mat)

  sam_boot <- matrix(sample(1:n, size = n * n_boot, replace = TRUE),
                     ncol = n_boot)
  for (k in 1:n_boot) {
    ind_samp <- sam_boot[, k]
    S_samp <- stats::var(xx2[ind_samp, ])
    cov_est <- fastcclasso_sub_CLR(
      lambda, SS2 = S_samp, aa = aa, bb = bb,
      k_max = 200, x_tol = stop_eps
    )
    vars_boot[, k] <- diag(cov_est$sigma)
    Is <- 1 / sqrt(vars_boot[, k])
    cor_est <- Is * cov_est$sigma * rep(Is, each = p)
    cors_boot[, k] <- cor_est[ind_low]
  }

  vars_boot[, n_boot + 1] <- diag(sigma_hat)
  Is <- 1 / sqrt(vars_boot[, n_boot + 1])
  cor_est <- Is * sigma_hat * rep(Is, each = p)
  cors_boot[, n_boot + 1] <- cor_est[ind_low]

  vars2 <- rowMeans(vars_boot)
  cors2mod <- rowMeans(cors_boot)
  cors2_mat <- diag(p)
  cors2_mat[ind_low] <- cors2mod
  cors2_mat <- t(cors2_mat)
  cors2_mat[ind_low] <- cors2mod

  p_vals <- stats::pt(
    cors2mod * sqrt((n - 2) / (1 - cors2mod^2)),
    df = n - 2
  )
  p_vals <- ifelse(p_vals <= 0.5, p_vals, 1 - p_vals)
  pval_mat <- diag(p)
  pval_mat[ind_low] <- p_vals
  pval_mat <- t(pval_mat)
  pval_mat[ind_low] <- p_vals

  list(var_w = vars2, cor_w = cors2_mat, p_vals = pval_mat)
}

# Apply multiple-testing correction outside the fastCCLasso estimator.
#
# The original fastCCLasso p-values are retained unchanged by
# fastCCLasso_CLR(). CoMeDA calls this helper when selecting network edges.
# For a standard network, each unordered taxon pair is one hypothesis. For a
# cross-dataset network, only pairs spanning the two datasets are hypotheses.
adjust_fastCCLasso_pvalues <- function(p_values,
                                       scope = c("all_pairs", "cross_block"),
                                       split_index = NULL,
                                       method = "BH") {
  scope <- match.arg(scope)
  p_values <- as.matrix(p_values)

  if (!is.numeric(p_values) || nrow(p_values) != ncol(p_values)) {
    stop("p_values must be a numeric square matrix.")
  }

  p <- nrow(p_values)
  adjusted <- matrix(NA_real_, nrow = p, ncol = p,
                     dimnames = dimnames(p_values))

  if (scope == "all_pairs") {
    pair_index <- which(lower.tri(p_values), arr.ind = TRUE)
    raw <- p_values[pair_index]
    valid <- is.finite(raw) & !is.na(raw)
    adjusted_values <- rep(NA_real_, length(raw))
    adjusted_values[valid] <- stats::p.adjust(raw[valid], method = method)
    adjusted[pair_index] <- adjusted_values
    adjusted <- t(adjusted)
    adjusted[pair_index] <- adjusted_values
    diag(adjusted) <- 1
  } else {
    if (length(split_index) != 1L || !is.finite(split_index) ||
        split_index < 1L || split_index >= p) {
      stop("split_index must separate two non-empty column blocks.")
    }
    split_index <- as.integer(split_index)
    first <- seq_len(split_index)
    second <- (split_index + 1L):p
    raw <- as.vector(p_values[first, second, drop = FALSE])
    valid <- is.finite(raw) & !is.na(raw)
    adjusted_values <- rep(NA_real_, length(raw))
    adjusted_values[valid] <- stats::p.adjust(raw[valid], method = method)
    adjusted_block <- matrix(adjusted_values,
                             nrow = length(first),
                             ncol = length(second))
    adjusted[first, second] <- adjusted_block
    adjusted[second, first] <- t(adjusted_block)
  }

  adjusted
}
