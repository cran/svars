#' @method plot sboot
#' @export

plot.sboot <- function(x, scales = "free_y", lowerq = 0.16, upperq = 0.84, percentile = 'standard', selection = NULL,
                       cumulative = NULL, ..., base){
  # define
  probs <- NULL
  V1 <- NULL
  value <- NULL

  # Auxiliary functions
  cutt <- function(x, selind){
    x$irf <- x$irf[selind]  ## account for the first column being "V1" the horizon counter
    return(x)
  }

  agg <- function(x, aggind){
    x$irf[,aggind] <- cumsum(x$irf[aggind])
    return(x)
  }

  # To select shocks and variables to plot
  kk <- ncol(x$true$irf)
  k <- sqrt(kk - 1)

  ### Calculate cumulated irfs if necessary
  if(!is.null(cumulative)){
      aggind <- list()
      temp <- (k * cumulative) + 1
      for(i in 1:length(temp)){
        aggind[[i]] <- temp[i] - (k - c(1:k))
      }
      aggind <- unlist(aggind)

    x$true      <- agg(x$true, aggind)
    x$bootstrap <- lapply(x$bootstrap, agg, aggind)
  }

  # Select specific shocks or series
  if(!is.null(selection)){
    selind <- list()
    temp <- (k * selection[[1]]) + 1 ## for the column V1
    for(i in 1:length(temp)){
      selind[[i]] <- temp[i] - (k - selection[[2]])
    }
    selind <- c(1, unlist(selind))

    x$true      <- cutt(x$true, selind)
    x$bootstrap <- lapply(x$bootstrap, cutt, selind)

    kk <- ncol(x$true$irf)
  }

  n.ahead <- nrow(x$true$irf)

  bootstrap <- x$bootstrap
  nboot <- length(bootstrap)
  rest <- x$rest_mat

  n.probs <- length(lowerq)
  if(length(lowerq) != length(upperq)){
    stop("Vectors 'lowerq' and 'upperq' must be of same length!")
  }

  intervals <- array(0, c(n.ahead, kk, nboot))
  for(i in 1:nboot){
    intervals[,,i] <- as.matrix(bootstrap[[i]]$irf)
  }

  # find quantiles for lower and upper bounds
  lower <- array(0, dim = c(n.ahead, kk, n.probs))
  upper <- array(0, dim = c(n.ahead, kk, n.probs))
  if(percentile == 'standard' | percentile == 'hall'){
    for(i in 1:n.ahead){
      for(j in 1:kk){
        lower[i,j, ] <- quantile(intervals[i,j, ], probs = lowerq)
        upper[i,j, ] <- quantile(intervals[i,j, ], probs = upperq)
      }
    }

    if(percentile == 'hall'){
      for(p in 1:n.probs){
        lower[ ,-1, p] <- as.matrix(2*x$true$irf)[ ,-1] - lower[ ,-1, p]
        upper[ ,-1, p] <- as.matrix(2*x$true$irf)[ ,-1] - upper[ ,-1, p]
      }
    }

  }else if(percentile == 'bonferroni'){
    rest <- matrix(t(rest), nrow = 1)
    rest[is.na(rest)] <- 1
    rest <- c(1, rest)
    for(i in 1:n.ahead){
      for(j in 1:kk){
        if(rest[j] == 0){
          lower[i,j, ] <- quantile(intervals[i,j, ], probs = (lowerq/n.ahead))
          upper[i,j, ] <- quantile(intervals[i,j, ], probs = 1 + (((upperq - 1)/n.ahead)))
        }else{
          lower[i,j, ] <- quantile(intervals[i,j, ], probs = (lowerq/(n.ahead + 1)))
          upper[i,j, ] <- quantile(intervals[i,j, ], probs = 1 + (((upperq - 1)/(n.ahead + 1))))
        }
      }
    }
  }else{
    stop("Invalid choice of percentile; choose between standard, hall and bonferroni")
  }

  # plot IRF with confidence bands
  alp <- 0.7 * (1+log(n.probs, 10))/n.probs
  irf <- melt(x$true$irf, id = 'V1')
  cbs <- data.frame(V1 = rep(irf$V1, times=n.probs),
               variable = rep(irf$variable, times=n.probs),
               probs = rep(1:n.probs, each=(kk-1)*n.ahead),
               lower = c(lower[,-1,]),
               upper = c(upper[,-1,]))
  ggplot() +
    geom_ribbon(data=cbs, aes(x=V1, ymin=lower, ymax=upper, group=probs), alpha=alp, fill='darkgrey') +
    geom_line(data=irf, aes(x=V1, y=value)) +
    geom_hline(yintercept = 0, color = 'red') +
    facet_wrap(~variable, scales = scales, labeller = label_parsed) +
    xlab("Horizon") + ylab("Response") +
    theme_bw()
}
