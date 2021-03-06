#### Lean Mass Annalysis ####

library(data.table); library(tidyverse)

#### Extra Paths####
if (!exists('base.path')) {
  if(.Platform$"OS.type" == "windows"){
    base.path = file.path("D:", "Dropbox", "wintor_aux")
  } else {
    base.path = "~/Dropbox/winTor_aux"
  }
}

win.dat <- file.path(base.path, "data")
win.res <- file.path(base.path, "Results")
## Serdp new data
serdp.newDat <- file.path("D:", "Dropbox", 
                          "SERDP", "data_source", "NewestData")

## The %!in% opperator 
'%!in%' <- function(x,y)!('%in%'(x,y))

#### Create the cleaned dataset to work from ####
# ##Serdp data
# library(readxl)
# excel_sheets(file.path(serdp.newDat, "Bat Morphometrics.xlsx"))
# qmr.dat <- read_excel(file.path(serdp.newDat, "Bat Morphometrics.xlsx"),
#                          sheet = "Bat Morphometrics",
#                       na = "", guess_max = 2000)
# colnames(qmr.dat)
# 
# qmr.sub <- qmr.dat %>%
#   dplyr::filter(`Species` == "Myotis lucifugus") %>% ##filter species
#   separate(`Date`,  c("d","m","y")) %>% ##set up dates
#    filter(m %in% c("09","10","11"), ## filter dates to per-hibernation
#          Age == "Adult", ##filter adults
#          !is.na(`Fat Mass`), ##filter to only those with qmr
#          `Site ID` == "LCC")%>% ##only MT bats (only one UT)
#   dplyr::select(`ID`, `Site ID`, `Age`, ##Simplify data structure
#                 `Sex`, `Forearm Length`, `Body Mass`,
#                 `Fat Mass`, `Lean Mass`, m)
# 
# # standarize col names
# colnames(qmr.sub) <- c("batID", "siteName", "age",
#                        "sex", "forearm", "mass",
#                        "fat", "lean", "month")
# # add state
# qmr.sub$state <- "MT"
# 
# ## are there duplicates
# duplicated(qmr.sub$batID) #no
# 
# ##Data from body condition paper
# bcp <- fread(file.path(win.dat,"QMR_Data_All_3Sept2017.csv"))
# bcp$Date1 <- as.Date(bcp$Date1, "%d-%b-%y")
# 
# bcp.sub <- bcp %>%
#   filter(Species == "Myotis lucifugus",
#          !is.na(Fat)) %>%
#   separate(Date1, c("y", "m", "d")) %>%
#   filter(m %in% c("09","10","11")) %>%
#   dplyr::select(ID, `Site Name`, Age, Sex, Forearm,
#          Mass, Fat, Lean, m, State)
# 
# #standrize col names
# colnames(bcp.sub) <- c("batID", "siteName", "age",
#                        "sex", "forearm", "mass",
#                        "fat", "lean", "month", "state")
# ## are there duplicates
# which(duplicated(bcp.sub$batID)) #none
# unique(bcp.sub$state)
# 
# ## Bind
# dat <- bind_rows(qmr.sub, bcp.sub)
# library(skimr)
# skim(dat)
# 
# ## Clean some more
# dat.clean <- dat %>%
#   mutate(age = substring(age, 1, 1), ## create consistent naming for these
#          sex = substring(sex, 1, 1)) %>%
#   filter(age == "A",  #remove the sub adult
#          state != "ON") # remove ON because it only has 2 instances
# str(dat.clean)
# 
# ##Checkpoint
# write.csv(dat.clean,
#           file = "data/qmrCleaned.csv", row.names = F)


dat.clean <- fread("data/qmrCleaned.csv")
## filter outliers
dat.clean <- dat.clean %>%
  filter(fat > 0.85)
head(dat.clean)

## plot the !$
ggplot(data = dat.clean, ##mass
       aes(x= siteName, y = mass)) +
  geom_point()

ggplot(data = dat.clean, ##fat
       aes(x= siteName, y = fat)) +
  geom_point()

ggplot(data = dat.clean, ## lean
       aes(x= siteName, y = lean)) +
  geom_point()

ggplot(data = dat.clean, ## forearm
       aes(x= siteName, y = forearm)) +
  geom_point()

## proportional QMR mass
dat.clean  <- dat.clean %>%
  mutate(fl = fat + lean,
         flp = fl/mass)

##plot this
ggplot(data = dat.clean, ## flp
       aes(x= siteName, y = flp)) +
  geom_point()
## LCC data looks suspect af
plot(cor(dat.clean[,c(5:8,11:12)]))

## set factors
dat.clean$sex <- as.factor(dat.clean$sex)
dat.clean$state <- as.factor(dat.clean$state)

## create thesholding for
other <- dat.clean %>%
  filter(siteName != "LCC")
ggplot(data = other, ## ohter
       aes(x= siteName, y = flp)) +
  geom_point()

dat.1 <- dat.clean %>%
  filter(flp > .87, 
         flp < .96)

ggplot(data = dat.1, ##flp post clean
       aes(x= siteName, y = flp)) +
  geom_point()

## visulize with sex
ggplot(data = dat.clean, ##mass
       aes(x= siteName, y = mass, color = sex)) +
  geom_point()

ggplot(data = dat.clean, ##fat
       aes(x= siteName, y = fat, color = sex)) +
  geom_point()

ggplot(data = dat.clean, ## lean
       aes(x= siteName, y = lean, color = sex)) +
  geom_point()

ggplot(data = dat.clean, ## forearm
       aes(x= siteName, y = forearm, color = sex)) +
  geom_point()

#### New modeling ####
fat.pred <- lm(fat ~ mass, dat.clean)
summary(fat.pred)



#### Start modleing #### The code below this point is no longer used
#### Outlier removal ####
### After taking a look at the inital plots, it appears that some of the Montana
### bats may be outliers (one in particular has a very low amount of fat)
  ##cross validation of points using studentized residuals
library(caret);library(rlang)
cross.lm <- function(predictor, forms, x){
  ##function for preforming leave one out crossvalidation and determing
  ##which points are potentially over influencing the models
  # pred is to be what you want to predict
  # forms is a list of formulas generated by mod.form
  # x is the dataframe from which all the data comes from
  
  ##control statment for caret
  train_control <- trainControl(method="LOOCV", returnResamp = "all")
  
  # run the leave one out validation on each of the points and return pvals
  pred = list()
  for (i in 1:nrow(x)) {
    test = x[i,]
    train = x[-i,]
    mod = lm(forms, data=train)
    pred_fit = predict.lm(mod, test, interval="prediction", se.fit=TRUE)
    pred[[i]] <- cbind(pred_fit$fit,
                       se=pred_fit$se.fit,
                       res.scale=pred_fit$residual.scale,
                       df=pred_fit$df,
                       obs=test[,..predictor])
  }
  
  pred = bind_rows(lapply(pred, as.data.frame))
  colnames(pred)[ncol(pred)] <- "obs"
  
  ## finds p val for observations, if outside of window of obs adj.pval will be low
  pval.pred <- pred %>% mutate(pred.sd = sqrt(se^2 + res.scale^2),
                               tval = (obs - fit) / pred.sd,
                               pval = 2*pt(abs(tval), df=df, lower.tail = FALSE)) %>%
    mutate(padj = p.adjust(pval)) %>% arrange(pval) %>%
    dplyr::filter(padj < 1)
  
  if(nrow(pval.pred) > 0){
    out <- list(df = as.data.frame(pval.pred),formula =  forms)  
  } else{
    out <- NA
  }
  
  return(out)
}

fat.cross <- cross.lm(predictor = "fat",
                      forms = as.formula(fat ~ mass),
                      x = dat.clean)

## From this it appears that we have 3 data points significanyly changing the
## quality of our predictions. Remove and repredict
dat.sub <- dat.clean[-which(dat.clean$fat %in% fat.cross$df$obs),]




#### Modeling round 2###
## Effect of sex

lean.sex <- lm(lean~sex, dat.sub)
summary(lean.sex)

lean.state.sex <- lm(lean~state*sex, dat.sub)
summary(lean.state.sex)
lean.state.sex1 <- update(lean.state.sex, .~. - state:sex)
summary(lean.state.sex1)

##hsd for differences 
library(multcomp)
ph <- glht(lean.state.sex1, linfct=mcp(state="Tukey"))
summary(ph)
## There is a significant differnce between Eastern and Western states in this instance

state.lean.plot <- ggplot(data = dat.sub) +
  geom_boxplot(aes(x = state, y = lean, color = state))+
  theme_bw()

# ggsave("fig/StateLean.pdf",
#        state.lean.plot)


## Predicting fat from body mass
fat.body <- lm(fat ~ mass, dat.sub)
summary(fat.body)

## Create plot

fat.mass.plot <- ggplot(dat.sub) + 
  geom_point(aes(x = mass, y = fat, color = state), show.legend = F) + 
  geom_abline(aes(intercept = fat.body$coefficients[[1]],
                  slope = fat.body$coefficients[[2]])) +
  annotate("text",
           x=7.9, y = 3.5,
           label = paste0("Fat Mass = ",round(fat.body$coefficients[[1]],2)," + ",
                          round(fat.body$coefficients[[2]],2)," * Mass")) +
  xlab("Mass (g)") +
  ylab("Fat mass (g)") + 
  theme_bw()


# ggsave("fig/FatMassLM.pdf",
#        fat.mass.plot)


fat.plots <- gridExtra::grid.arrange(state.lean.plot, fat.mass.plot,
                                     nrow = 1)
ggsave(file.path(win.res, "fig", "stateXfat.png"),
       fat.plots,
       device = "png",
       width = 9,
       height = 4,
       units = "in")


#### predict fat mass from collected data ####
new.df <- data.frame(mass = dat.clean$mass)
dat.clean$pred.fat <- predict.lm(object = fat.body, newdata = new.df)
