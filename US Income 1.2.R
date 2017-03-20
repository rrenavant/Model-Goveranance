trainpct <- 0.8
seed     <- 100
cv_vars <-  helper("data/credit_vision/credit_vision_variables")

list(
     import =
     income_verified(start='2015-07-01',end='2015-10-31') ~ credit_vision + transunion313 + transunion + rails_state + rails_fico + income_by_zip %s3key% 'tmp/income_1.2/data/yue/df_full_vef_151218'

     , data = list(
                     "Require necessary packages"            = list( function (.) { Ramd::packages('statsUtils'); . })
                    , "Remove any rows w > 30% missing"      = list( remove_sparse_rows, threshold = 0.3)
                    , "Restrict to loans with credit-vision" = list( select_rows ~ NULL, whole = TRUE, function(dataframe) {apply(is.na(dataframe[, intersect(names(dataframe), cv_vars)]), 1, function(x) mean(x) < 0.8)} )
                    , "Ordering by loan id"                  = list( orderer ~ NULL, "loan_id" )
                    , "Make validation set"                  = list( make_validation_set, seed = seed, trainpct = trainpct, use_latest = FALSE)
                    , "Create phi fi20s variable"            = list( multi_column_transformation(function(x,y) as.numeric(x / y)), c('fi20s', 'G104'), 'phi_oldest_finance_installment_trade_opened')
                    , "Create phi FICO variable"             = list( multi_column_transformation(function(x,y) as.numeric(x / y)), c('external_model_2_score', 'G104'), 'phi_FICO')
                    , "Create delta in20s,fi20s variable"    = list( multi_column_transformation(function(x,y) as.numeric(x - y)), c('in20s', 'fi20s'), 'delta_finance_non_finance_installment')
                    , "Create phi of last variable"          = list( multi_column_transformation(function(x,y,z) as.numeric((x - y)/ z)), c('in20s', 'fi20s', 'G104'), 'time_ratio_of_delta_finance_non_finance_installment')
                    , "Replace NAs with Missing level"       = list( value_replacer, is.factor, list(list(NA, 'Missing')) )
                    , "Group minor levels"                   = list( group_minor_levels, is.factor, min_pct = 0.01, exclude = c(NA, 'Missing', ''))
                    , "Restore categorical variables"        = list( restore_categorical_variables, is.factor )
                    , "Remove zero variance columns"         = list( drop_variables, function(x) identical(1L, statsUtils::nearZeroVar(data.frame(x))) )
                    , "Add weights"                          = list( resource("lib/shared/attach_weight")('simple') )
                    )

     , model = resource("lib/shared/xgb_parameters")(
                        nround           = 6500
                      , eta              = 0.01
                      , subsample        = 0.7
                      , colsample_bytree = 0.35
                      , weight           = TRUE
                      , objective        = "reg:linear"
                      , metrics          = "rmse")
    # , model_card = list(n=1)
     , export = list(
       s3 = 'income/en-US/1.2/eddie_full_vef_151214',
       s3data = 'income/en-US/1.2/data/eddie_full_vef_151214'
     )
)
