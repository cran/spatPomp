## extra tests of correctness requiring addition Monte Carlo intensity

set.seed(42)
library(spatPomp)

  print("Test PF/KF consistency for bm")
  bb <- bm(U=4,N=10)
  bb_pf_loglik <- round(logLik(pfilter(bb,1000)),10)
  print(paste("bm pfilter loglik: ",bb_pf_loglik))
  print(paste("bm kalman filter loglik: ",round(bm_kalman_logLik(bb),10)))

  print("Test PF/KF consistency for bm2")
  bb2 <- bm2(U=4,N=10)
  bb2_pf_loglik <- round(logLik(pfilter(bb2,1000)),10)
  print(paste("bm2 pfilter loglik: ",bb2_pf_loglik))
  print(paste("bm2 kalman filter loglik: ",round(bm2_kalman_logLik(bb2),10)))

  print("Test PF/KF consistency for bm2 with unequal parameters")
  U <- 4
  bb3 <- bm2(U=U,N=10,unit_specific_names=c("rho","sigma","tau","X_0"))
  coef(bb3)[paste("rho",1:U)]=seq(from=0.2,to=0.8,length=U)
  coef(bb3)[paste("sigma",1:U)]=seq(from=0.8,to=1.2,length=U)
  coef(bb3)[paste("tau",1:U)]=seq(from=0.5,to=1.5,length=U)
  coef(bb3)[paste("X_0",1:U)]=seq(from=-1,to=1,length=U)
  bb3 <- simulate(bb3)
  bb3_pf_loglik <- round(logLik(pfilter(bb3,1000)),10)
  print(paste("bm3 pfilter loglik: ",bb3_pf_loglik))
  print(paste("bm3 kalman filter loglik: ",round(bm2_kalman_logLik(bb3),10)))






