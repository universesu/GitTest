-- ============================================================
-- Author:		Ying Cheng, Fangyu Su
-- Create date: --/--/----
-- Latest Update date: 12/07/2016
-- Description:	Query about traffic and cost of the applicants
--              (including affiliate and organic)
-- ============================================================

DECLARE @StartDate SMALLDATETIME
DECLARE @EndDate SMALLDATETIME

SET @StartDate = '01/02/2019'
SET @EndDate =   '05/07/2019'



;WITH AffTracker AS
   (SELECT

     APP.ID AS ApplicatID

     ,CONVERT(DATE, BAL.DATE) AS ReceivedDte
     ,MONTH(APP.Dte) AS ReceivedMonth
--   ,DATENAME(ww, APP.Dte) AS WeekNum
--   ,DATEPART(WEEKDAY,APP.Dte)-1 AS AppWD
     ,APP.Social
     ,ApplyBefore.TimesAppliedAll
     ,CASE WHEN ApplyBefore.TimesAppliedAll= 1 THEN 'Y' ELSE 'N' END AS BrandNew
--   ,ApplyBefore.MIN_Salary
 --,case when DATEDIFF(DAY, CONVERT(DATE,APP.DOB), CONVERT(DATE, APP.DTE))/365>1000 then
	-- DATEDIFF(DAY, CONVERT(DATE,APP.DOB), CONVERT(DATE, APP.DTE))/365-1000 else DATEDIFF(DAY, CONVERT(DATE,APP.DOB), CONVERT(DATE, APP.DTE))/365 end AS Age
     ,APP.DOB
	 ,convert(date,APP.DTE) as DTE
	 ,APP.Salary
     --,PRE.Distribution AS PreChecScore
     --,PRE.Status AS PreCheckDecision
     ,GVC.ResponseCode
     ,convert(date,GVC.InquiryDate) as InquiryDate
     ,APP.State
	 ,states.abbr
     --,Stability.Distribution AS StabilityScore
     --,Stability.Status AS StabilityDecision
     --,RF.Distribution AS RFScore
     --,RF.Status AS RFDecision
     --,LT.Distribution AS LTScore
     --,LT.Status AS LTDecision
     --,SMT.Model
     ,SMT.Decision
     ,FT.FactorTrustResponseID
     ,FT.RiskScore
	 ,FT.storeID
     --,SMT.StoreID AS TrackingID
     ,APP.Type AS ApplicantType
     ,ISNULL(AFF.LeadPrice,0.00) AS LeadPrice
     ,ISNULL(CONVERT(DECIMAL(10,2),APP.Loanamount),0)AS Loanamount

     ,CONVERT(DATE, BAL.Date) AS BoughtDte
     ,BAL.Status AS BuyStatus
	 ,CASE
           WHEN APP.AffID = 'x' THEN 'Organic' ELSE AFF.Name END AS Affiliate

FROM  [Mypayday].[dbo].[BuyAppsLog] BAL WITH(NOLOCK)
INNER JOIN Mypayday.dbo.Applicant APP WITH (NOLOCK)
ON BAL.ApplicantID = APP.ID
left join mypayday.dbo.[States] states with(nolock) on app.state=states.name

LEFT OUTER JOIN Mypayday.dbo.Affiliate AFF WITH (NOLOCK)
     ON LEFT(APP.Extra2,CHARINDEX('-',APP.Extra2)-1) = CAST(AFF.AffiliateID AS VARCHAR(5))
     OUTER APPLY (SELECT TOP 1 FTR.FactorTrustResponseID , FTR.RiskScore,FTR.storeID FROM [Mypayday].[dbo].[FactorTrustResponse] FTR WITH (NOLOCK)
                           WHERE FTR.ApplicantID=APP.ID ) FT

     --Times applied so far, no time frame
     CROSS APPLY
     (SELECT    COUNT(*) AS TimesAppliedAll,
              MIN(CASE WHEN CHARINDEX('$',AP.Salary)>0 THEN RIGHT(AP.Salary,LEN(AP.Salary)-1) ELSE CONVERT(DECIMAL(22,8),AP.Salary) END) AS MIN_Salary
                FROM [Mypayday].dbo.Applicant AP WITH (NOLOCK)  WHERE AP.Social =APP.Social AND AP.ID <=APP.ID)ApplyBefore
     --OUTER APPLY (SELECT TOP 1 Distribution, Status FROM [Mypayday].[dbo].[FisLog] FIS WITH (NOLOCK) WHERE APP.ID = FIS.ApplicantID AND FIS.LogType = 'Precheck' ) Pre
     --OUTER APPLY (SELECT TOP 1 Distribution, Status FROM [Mypayday].[dbo].[FisLog] FIS WITH (NOLOCK) WHERE APP.ID = FIS.ApplicantID AND FIS.LogType = 'StabilityModel' ) Stability
     --OUTER APPLY (SELECT TOP 1 Distribution, Status FROM [Mypayday].[dbo].[FisLog] FIS WITH (NOLOCK) WHERE APP.ID = FIS.ApplicantID AND FIS.LogType = 'AzureRandomForest' ) RF
     --OUTER APPLY (SELECT TOP 1 Distribution, Status FROM [Mypayday].[dbo].[FisLog] FIS WITH (NOLOCK) WHERE APP.ID = FIS.ApplicantID AND FIS.LogType NOT IN ('Precheck','StabilityModel','Stability','AzureRandomForest' )) LT

     OUTER APPLY (SELECT TOP 1 Model, Decision, StoreID FROM Mypayday.dbo.ScoreModelTracking SM WITH (NOLOCK) WHERE APP.ID = SM.ApplicantID AND SM.Model IN
	 ('FactorTrustModel','BayesianNetwork','LogisticRegressionOld','LogisticRegressionNew' ) ORDER BY SM.ScoreModelTrackingID ASC) SMT


     OUTER APPLY
                     (SELECT TOP 1 GV.ResponseCode,
                                       GV.InquiryDate
     FROM GatewayACH.dbo.CustomerBankAccount CB WITH (NOLOCK) INNER JOIN GatewayACH.dbo.GverifyLog GV WITH (NOLOCK)
           ON CB.BankAccountID = GV.BankAccountID

     WHERE
           CB.Routing = APP.Routingnum AND CB.Account = APP.Checkaccountnum
           AND DATEDIFF(DAY,CONVERT(DATE,GV.InquiryDate),CONVERT(DATE, APP.Dte))<=1
           AND GV.InquiryLocationID IN ('2','5')
           ORDER BY GV.InquiryDate DESC
     ) GVC


     WHERE
     CONVERT(DATE, BAL.DATE) BETWEEN @StartDate AND @EndDate
     AND APP.Type IS NOT NULL

     --AND ISNULL(AFF.LeadPrice,0.00) >0
	 --and FT.storeID='0013'
	 --and CONVERT(DECIMAL(10,2),APP.Loanamount)='500'
	 --and BAL.Status ='accepted'
     )



     SELECT


     --AFT.state
  --   SUM(CASE WHEN AFT.ApplicantType IS NOT NULL THEN 1 ELSE 0 END) AS TotalApps
  --   --,SUM(CASE WHEN AFT.Loanamount =500 THEN 1 ELSE 0 END) AS Received_500
	 --,SUM(CASE WHEN AFT.Affiliate='Organic' THEN 1 ELSE 0 END)AS Received_Organic
  --   ,SUM(CASE WHEN AFT.ResponseCode IS NOT NULL THEN 1 ELSE 0 END) AS RungVerify
  --   ,SUM(CASE WHEN AFT.ResponseCode IN ('1111','3333') THEN 1 ELSE 0 END ) AS  acpt_g
  --   ,SUM(CASE WHEN AFT.FactorTrustResponseID IS NOT NULL THEN 1 ELSE 0 END) AS Scored
  --   --,SUM(CASE WHEN AFT.Decision = 'approve' THEN 1 ELSE 0 END) AS TotalAccepted
  --   ,SUM(CASE WHEN AFT.BuyStatus = 'accepted' THEN 1 ELSE 0 END ) AS Bought
  --   ,SUM(CASE WHEN AFT.BuyStatus = 'accepted' THEN AFT.LeadPrice ELSE 0 END) AS LeadCost
  --   ,SUM(CASE WHEN AFT.ApplicantType = 'Pre-approved' THEN 1 ELSE 0 END) AS 'Pre-approved'
  --   ,SUM(CASE WHEN AFT.ApplicantType = 'Expired' THEN 1 ELSE 0 END) AS Expired
  --   ,SUM(CASE WHEN AFT.ApplicantType = 'Cancelled' THEN 1 ELSE 0 END) AS Cancelled
  --   ,SUM(CASE WHEN AFT.BuyStatus = 'accepted' AND AFT.ApplicantType = 'Rejected' THEN 1 ELSE 0 END) AS Rejected
  --   ,SUM(CASE WHEN AFT.ApplicantType ='approved' THEN 1 ELSE 0 END) AS Funded
     --,SUM(CASE WHEN AFT.ApplicantType ='approved' AND AFT.Loanamount =500  THEN 1 ELSE 0 END) AS Funded500

*

     FROM
     AffTracker AFT
     WHERE  AFT.ApplicantType IS NOT NULL
	 --and aft.age >62
   --AND AFT.Loanamount = 500
   --and AFT.RISKSCORE=111
   --AND AFT.Decision = 'approve'

--GROUP BY      AFT.state
--ORDER BY      AFT.state
