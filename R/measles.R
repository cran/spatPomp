#' Measles in UK spatPomp generator
#'
#' Generate a spatPomp object for measles in the top-\code{U} most populous cities in England and Wales.
#' The model is adapted from He et al. (2010) with gravity transport following Park and Ionides (2020).
#' The data are from Dalziel et al (2016).
#'
#' @name measles
#' @rdname measles
#' @author Edward L. Ionides
#' @family spatPomp model generators
#' @seealso \code{measles_UK}, \code{city_data_UK}
#'
#' @param U A length-one numeric signifying the number of cities to be represented in the spatPomp object.
#' @importFrom utils data read.csv write.table
#' @param dt a numeric (in unit of years) that is used as the Euler time-increment for simulating measles data.
#' @param fixed_ivps a logical. If \code{TRUE} initial value parameters will be
#' declared in the \code{globals} slot, shared for each unit, and
#' will not be part of the parameter vector.
#' @param S_0 a numeric. If \code{fixed_ivps=TRUE} this is the initial proportion of all of the spatial units that are susceptible.
#' @param E_0 a numeric. If \code{fixed_ivps=TRUE} this is the initial proportion of all of the spatial units that are exposed.
#' @param I_0 a numeric. If \code{fixed_ivps=TRUE} this is the initial proportion of all of the spatial units that are infected.
#' @return An object of class \sQuote{spatPomp} representing a \code{U}-dimensional spatially coupled measles POMP model.
#'
#' @section Relationship to published analysis:
#' This model was used to generate the results of Ionides et al (2021).
#' However, their equation (6) is not exactly correct for the Binomial Gamma infinitesimal model used in the code, as shown by Proposition 5 of Breto and Ionides, 2011.
#' If Poisson Gamma infinitesimal increments were used (Proposition 4 of Breto and Ionides, 2011) then (6) would be correct, but the resulting unbounded increments could break the non-negativity requirement for compartment membership.
#' The same issue arises with the description in Park and Ionides (2020), though that analysis was based on a different model implementation since the spatPomp package was not yet available.
#'
#' A difference between (6) of Ionides et al (2021) and (2.1) of He et al (2010) is that in (6) the mixing exponent \eqn{\alpha} is applied to \eqn{(I_u/P_u)} rather than just to \eqn{I_u}.
#' In the context of He et al (2010) this changes the parameterization but has negligible effect on the model itself since \eqn{P_u(t)} is approximately constant and so changing its power can be compensated by a corresponding change in the transmission rate, \eqn{\beta}.
#' In practice, models fitted to data have \eqn{alpha} close to \eqn{1}, so this issue may be moot and  this modeling mechanism may not be an effective empirical way to carry out the goal of making allowance for heterogeneous mixing.
#'
#' The code here includes a cohort effect, \eqn{c}, following He et al (2010), that was not included by Ionides et al (2021).
#' This effect leads to a non-differentiability of expected increments which is problematic for the spatPomp implementation of GIRF.
#' For the results of Ionides et al (2021), this was set to \eqn{c=0}.
#'
#' The analysis of He et al (2010), and the model generated by \code{he10()}, use weekly aggregated cases.
#' Weekly reports were not available beyond the 20 cites studied by He et al (2010) so \code{measles()} relies on the biweekly reports used by Ionides et al (2021) and Ionides & Park (2020).
#'
#' It turns out to be an important detail of the model by He et al (2010) that a delay is included between birth and entry into the susceptible compartment. 
#' He et al (2010) found a 4 year delay fits the data.
#' This value is fixed to be the variable \code{birth_delay} in the code for \code{measles()}.
#' The code for Ionides et al (2021) uses a 3 year delay, and the delay is not explained in the abbreviated model description.
#' In \code{measles()} we have reverted to the 4 year delay identified by He et al (2010).
#'
#' @references
#'
#' \ionides2021
#'
#' \dalziel2016
#'
#' \park2020
#'
#' \breto2011
#'
#' @note This function goes through a typical workflow of constructing
#' a typical spatPomp object (1-4 below). This allows the user to have a
#' file that replicates the exercise of model building as well as function
#' that creates a typical nonlinear model in epidemiology in case they want
#' to test a new inference methodology. We purposely do not modularize this
#' function because it is not an operational piece of the package and is
#' instead useful as an example.\cr
#' 1. Getting a measurements data.frame with columns for times,
#'    spatial units and measurements.\cr
#' 2. Getting a covariates data.frame with columns for times,
#'    spatial units and covariate data.\cr
#' 3. Constructing model components (latent state initializer,
#'    latent state transition simulator and measurement model). Depending
#'    on the methods used, the user may have to supply a vectorfield to
#'    be integrated that represents the deterministic skeleton of the latent
#'    process.\cr
#' 4. Bringing all the data and model components together to form a
#'    spatPomp object via a call to spatPomp().
#' @examples
#' # Complete examples are provided in the package tests
#' \dontrun{
#' m <- measles(U = 5)
#' # See all the model specifications of the object
#' spy(m)
#' }
#' @export

# NOTE: As indicated in the Note section of the documentation, this
# this function goes through a typical workflow of constructing
# a spatPomp object. It is not meant to be operational, but
# instead an example of how one goes about going from getting data to creating
# a spatPomp object.
measles <- function(U=6,dt=2/365,
                    fixed_ivps=TRUE,
                    S_0=0.032, E_0=0.00005, I_0=0.00004){

  birth_lag <- 4*26  # delay until births hit susceptibles, in biweeks

  # pre-vaccine biweekly measles reports for the largest 40 UK cities, sorted by size
  measlesUK <- spatPomp::measlesUK
  city_data_UK <- spatPomp::city_data_UK

  if(U>40) stop("Require U<=40 since data are only available for 40 cities")
  cities <- unique(measlesUK$city)[1:U]
  measles_cases <- measlesUK[measlesUK$city %in% cities,c("year","city","cases")]
  measles_cases <- measles_cases[measles_cases$year>1949.99,]
  measles_covar <- measlesUK[measlesUK$city %in% cities,c("year","city","pop","births")]
  u <- split(measles_covar$births,measles_covar$city)
  v <- sapply(u,function(x){c(rep(NA,birth_lag),x[1:(length(x)-birth_lag)])})
  measles_covar$lag_birthrate <- as.vector(v[,cities])*26
  measles_covar$births <- NULL

  # Haversine formula for great circle distance between two points
  # on a sphere radius r. Here, r defaults to a mean radius for the
  # earth, in miles.
  distGreatCircle <- function(p1, p2, r = 3963.191) {
    Lon1 <- p1[,1]*pi/180
    Lat1 <- p1[,2]*pi/180
    Lon2 <- p2[,1]*pi/180
    Lat2 <- p2[,2]*pi/180
    a <- sin((Lat2-Lat1)/2)^2 + cos(Lat1)*cos(Lat2)*sin((Lon2-Lon1)/2)^2
    atan2(sqrt(a), sqrt(1 - a)) * 2 * r
  }

  lon_lat <- city_data_UK[1:U,c("lon","lat")]
  dmat <- matrix(0,U,U)
  for(u1 in 1:U) {
    for(u2 in 1:U) {
      dmat[u1,u2] <- round(distGreatCircle(lon_lat[u1,],lon_lat[u2,]),1)
    }
  }

  p <- city_data_UK$meanPop[1:U]
  v_by_g <- matrix(0,U,U)
  dist_mean <- sum(dmat)/(U*(U-1))
  p_mean <- mean(p)
  for(u1 in 2:U){
    for(u2 in 1:(u1-1)){
      v_by_g[u1,u2] <- (dist_mean*p[u1]*p[u2]) / (dmat[u1,u2] * p_mean^2)
      v_by_g[u2,u1] <- v_by_g[u1,u2]
    }
  }
  to_C_array <- function(v)paste0("{",paste0(v,collapse=","),"}")
  v_by_g_C_rows <- apply(v_by_g,1,to_C_array)
  v_by_g_C_array <- to_C_array(v_by_g_C_rows)
  v_by_g_C <- Csnippet(paste0("const double v_by_g[",U,"][",U,"] = ",v_by_g_C_array,"; "))

## for the C code, we define fixed IVPs and parametric IVPs,
## but only the needed ones are actually used.
  if(fixed_ivps){
    ivps_fixed_C <- paste0("const double ", c("S_0_fixed", "E_0_fixed",
      "I_0_fixed"), " = ", c(S_0, E_0, I_0), collapse= ";\n")
    ivps_parametric_C <- paste0("const double ", c("S1_0", "E1_0", "I1_0"),
      " = ", c(0, 0, 0), collapse= ";\n") ## defined but not used
    ivps_C <- paste("const int fixed_ivps = 1", ivps_fixed_C,ivps_parametric_C, ";", sep = ";\n")
  } else {
    ivps_fixed_C <- paste0("const double ", c("S_0_fixed", "E_0_fixed",
      "I_0_fixed"), " = ", c(0, 0, 0), collapse= ";\n") ## defined but not used
    ivps_C <- paste("const int fixed_ivps = 0", ivps_fixed_C, ";",
      sep = ";\n")
  }
  measles_globals <- Csnippet(
    paste(v_by_g_C, ivps_C, sep = ";\n")
  )
  measles_unit_statenames <- c('S','E','I','R','C')
  measles_RPnames <- c("alpha","iota","psi","R0","gamma","sigma","sigmaSE","cohort","amplitude","mu","rho","g")

  if(fixed_ivps){
    measles_paramnames <- c(measles_RPnames)
  } else{
    measles_statenames <- paste0(rep(measles_unit_statenames,each=U),1:U)
    measles_IVPnames <- paste0(measles_statenames[1:(3*U)],"_0")
    measles_paramnames <- c(measles_RPnames,measles_IVPnames)
  }

  measles_rprocess <- spatPomp_Csnippet(
    unit_statenames = c('S','E','I','R','C'),
    unit_covarnames = c('pop','lag_birthrate'),
    code="
      int BS=0, SE=1, SD=2, EI=3, ED=4, IR=5, ID=6;
      double br, beta, seas, foi, dw;
      double rate[7], dN[7];
      double powVec[U];
      int obstime = 0;
      int u,v;
      // term-time seasonality
      t = (t-floor(t))*365.25;
      if ((t>=7&&t<=100) || (t>=115&&t<=199) || (t>=252&&t<=300) || (t>=308&&t<=356))
          seas = 1.0+amplitude*0.2411/0.7589;
        else
          seas = 1.0-amplitude;

      // transmission rate
      beta = R0*(gamma+mu)*seas;

      for (u = 0 ; u < U ; u++) {
        // needed for the Ensemble Kalman filter
       // or other methods making real-valued perturbations to the state
        // reulermultinom requires integer-valued double type for states
        S[u] = S[u]>0 ? floor(S[u]) : 0;
        E[u] = E[u]>0 ? floor(E[u]) : 0;
        I[u] = I[u]>0 ? floor(I[u]) : 0;
        R[u] = R[u]>0 ? floor(R[u]) : 0;

        // pre-computing this saves substantial time
        powVec[u] = pow(I[u]/pop[u],alpha);
      }

      // These rates could be inside the u loop if some parameters arent shared between units
      rate[SD] = mu;	
      rate[EI] = sigma;	
      rate[ED] = mu;	
      rate[IR] = gamma;	
      rate[ID] = mu;	

      for (u = 0 ; u < U ; u++) {
        // cohort effect
        if (fabs(t-floor(t)-251.0/365.0) < 0.5*dt)
          br = cohort*lag_birthrate[u]/dt + (1-cohort)*lag_birthrate[u];
        else
          br = (1.0-cohort)*lag_birthrate[u];

        // expected force of infection
        foi = pow( (I[u]+iota)/pop[u],alpha);
        // we follow Park and Ionides (2019) and raise pop to the alpha power
        // He et al (2010) did not do this.

        for (v=0; v < U ; v++) {
          if(v != u)
            foi += g * v_by_g[u][v] * (powVec[v] - powVec[u]) / pop[u];
        }

        // white noise (extrademographic stochasticity)
        dw = rgammawn(sigmaSE,dt);
        rate[SE] = beta*foi*dw/dt;  // stochastic force of infection

        // Poisson births
        dN[BS] = rpois(br*dt);

        // transitions between classes
	// For example, S[u] has 2 exit flows, SE and SD, which must be numbered consecutively,
	// in this case, SE=1 and SD=2. &rate[SE] and &dN[SE] are pointers to the first exit flow.
        reulermultinom(2,S[u],&rate[SE],dt,&dN[SE]);
        reulermultinom(2,E[u],&rate[EI],dt,&dN[EI]);
        reulermultinom(2,I[u],&rate[IR],dt,&dN[IR]);

        S[u] += dN[BS]   - dN[SE] - dN[SD];
        E[u] += dN[SE] - dN[EI] - dN[ED];
        I[u] += dN[EI] - dN[IR] - dN[ID];
        R[u] = pop[u] - S[u] - E[u] - I[u];
        C[u] += dN[IR];   // case reports modeled at time of removal/recovery
      }
    "
  )

  measles_dmeasure <- spatPomp_Csnippet(
    unit_statenames = 'C',
    unit_obsnames = 'cases',
    code="
      double m,v;
      double tol = 1e-300;
      double mytol = 1e-5;
      int u;

      lik = 0;
      for (u = 0; u < U; u++) {
        m = rho*(C[u]+mytol);
        v = m*(1.0-rho+psi*psi*m);
        // C < 0 can happen in bootstrap methods such as bootgirf
        if (C < 0) {lik += log(tol);} else {
          if (cases[u] > tol) {
            lik += log(pnorm(cases[u]+0.5,m,sqrt(v)+tol,1,0)-
              pnorm(cases[u]-0.5,m,sqrt(v)+tol,1,0)+tol);
          } else {
            lik += log(pnorm(cases[u]+0.5,m,sqrt(v)+tol,1,0)+tol);
          }
        }
      }
      if(!give_log) lik = (lik > log(tol)) ? exp(lik) : tol;
    "
  )

  measles_rmeasure <- spatPomp_Csnippet(
    unit_statenames='C',
    code="
      double *cases = &cases1;
      double m,v;
      double tol = 1.0e-300;
      int u;
      for (u = 0; u < U; u++) {
        m = rho*(C[u]+tol);
        v = m*(1.0-rho+psi*psi*m);
        cases[u] = rnorm(m,sqrt(v)+tol);
        if (cases[u] > 0.0) {
          cases[u] = nearbyint(cases[u]);
        } else {
          cases[u] = 0.0;
        }
      }
    "
  )

  measles_dunit_measure <- spatPomp_Csnippet("
    double mytol = 1e-5;
    double m = rho*(C+mytol);
    double v = m*(1.0-rho+psi*psi*m);
    double tol = 1e-300;
    // C < 0 can happen in bootstrap methods such as bootgirf
    if (C < 0) {lik = 0;} else {
      if (cases > tol) {
        lik = pnorm(cases+0.5,m,sqrt(v)+tol,1,0)-
          pnorm(cases-0.5,m,sqrt(v)+tol,1,0)+tol;
      } else {
        lik = pnorm(cases+0.5,m,sqrt(v)+tol,1,0)+tol;
      }
    }
    if(give_log) lik = log(lik);
  ")

  measles_eunit_measure <- spatPomp_Csnippet("
    ey = rho*C;
  ")

  measles_vunit_measure <- spatPomp_Csnippet("
    //consider adding 1 to the variance for the case C = 0
    double mytol = 1e-5;
    double m;
    m = rho*(C+mytol);
    vc = m*(1.0-rho+psi*psi*m);
  ")

  measles_munit_measure <- spatPomp_Csnippet("
    double binomial_var;
    double m;
    double mytol = 1e-5;
    m = rho*(C+mytol);
    binomial_var = rho*(1-rho)*C;
    M_psi = (vc > binomial_var) ? sqrt(vc - binomial_var)/m : 0;
  ")

  measles_rinit <- spatPomp_Csnippet(
    unit_statenames = c('S','E','I','R','C'),
    unit_covarnames = 'pop',
    code = "
      double m;
      int u;
      if(fixed_ivps){
        for (u = 0; u < U; u++) {
          m = (float)(pop[u]);
          S[u] = nearbyint(m*S_0_fixed);
          I[u] = nearbyint(m*I_0_fixed);
          E[u] = nearbyint(m*E_0_fixed);
          R[u] = pop[u]-S[u]-E[u]-I[u];
          C[u] = 0;
        }
      } else{
        const double *S_0 = &S1_0;
        const double *I_0 = &I1_0;
        for (u = 0; u < U; u++) {
          m = (float)(pop[u]);
          S[u] = nearbyint(m*S_0[u]);
          I[u] = nearbyint(m*I_0[u]);
          // Use I[u] and the two relvant rates to
          // compute E[u]. (gamma/sigma)*I[u]
          E[u] = nearbyint((gamma/sigma)*(float)(I[u]));
          R[u] = pop[u]-S[u]-E[u]-I[u];
          C[u] = 0;
        }
      }
    "
  )

  measles_skel <- spatPomp_Csnippet(
    unit_statenames = c('S','E','I','R','C'),
    unit_vfnames = c('S','E','I','R','C'),
    unit_covarnames = c('pop','lag_birthrate'),
    code = "
      double beta, br, seas, foi;
      double powVec[U];
      int u,v;
      int obstime = 0;

      // term-time seasonality
      t = (t-floor(t))*365.25;
      if ((t>=7&&t<=100) || (t>=115&&t<=199) || (t>=252&&t<=300) || (t>=308&&t<=356))
          seas = 1.0+amplitude*0.2411/0.7589;
        else
          seas = 1.0-amplitude;

      // transmission rate
      beta = R0*(gamma+mu)*seas;

      // pre-computing this saves substantial time
      for (u = 0 ; u < U ; u++) {
        powVec[u] = pow(I[u]/pop[u],alpha);
      }

      for (u = 0 ; u < U ; u++) {
        // cannot readily put the cohort effect into a vectorfield for the skeleton
        // therefore, we ignore it here.
        // this is okay as long as the skeleton is being used for short-term forecasts
        //    br = lag_birthrate[u];

        // cohort effect, added back in with cohort arriving over a time interval 0.05yr
        if (fabs(t-floor(t)-251.0/365.0) < 0.5*0.05)
          br = cohort*lag_birthrate[u]/0.05 + (1-cohort)*lag_birthrate[u];
        else
          br = (1.0-cohort)*lag_birthrate[u];

        foi = I[u]/pop[u];
        for (v=0; v < U ; v++) {
          if(v != u)
            foi += g * v_by_g[u][v] * (I[v]/pop[v] - I[u]/pop[u]) / pop[u];
        }

        DS[u] = br - (beta*foi + mu)*S[u];
        DE[u] = beta*foi*S[u] - (sigma+mu)*E[u];
        DI[u] = sigma*E[u] - (gamma+mu)*I[u];
        DR[u] = gamma*I[u] - mu*R[u];
        DC[u] = gamma*I[u];
      }
    "
  )

  if(fixed_ivps){
    measles_partrans <- parameter_trans(
      log=c("sigma", "gamma", "sigmaSE", "psi", "R0", "g"),
      logit=c("amplitude", "rho")
    )
  } else {
    measles_partrans <- parameter_trans(
      log=c("sigma", "gamma", "sigmaSE", "psi", "R0", "g"),
      logit=c("amplitude", "rho",measles_IVPnames)
    )
  }

  spatPomp(measles_cases,
          units = "city",
          times = "year",
          t0 = min(measles_cases$year)-1/26,
          unit_statenames = measles_unit_statenames,
          covar = measles_covar,
          rprocess=euler(measles_rprocess, delta.t=dt),
          skeleton=vectorfield(measles_skel),
          unit_accumvars = c("C"),
          paramnames=measles_paramnames,
          partrans=measles_partrans,
          globals=measles_globals,
          rinit=measles_rinit,
          dmeasure=measles_dmeasure,
          eunit_measure=measles_eunit_measure,
          munit_measure=measles_munit_measure,
          vunit_measure=measles_vunit_measure,
          rmeasure=measles_rmeasure,
          dunit_measure=measles_dunit_measure
  )
}
