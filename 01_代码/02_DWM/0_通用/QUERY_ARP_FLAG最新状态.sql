/*******************************************************************************
 *                                  查询说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261106 19:05
 * 本次修改：ALTER BY 20261106 19:05 SHIQINGFENG.EX 新增 ARP_FLAG 最新状态监控查询。
 *
 * 查询名称  ：AW_RUL_DWMCRS_000001 ARP_FLAG 最新状态监控
 * 源表      ：TGK_FIMA_HISENSE.AW_RUL_DWMCRS_000001、TGK_FIMA_HISENSE.AW_RUL_DWMCRS_000001_LOG，详见正文。
 *
 * 修改历史：
 *   ALTER BY 20261106 19:05 SHIQINGFENG.EX 新增 ARP_FLAG 最新状态监控查询。
 *******************************************************************************/
WITH
/* 当前生效的 ARP_FLAG：同一公司在多个场景下都有配置时，取最近更新的一条。 */
CUR_ARP AS (
    SELECT COD_AZIENDA
         , ARP_FLAG
         , USERUPD
         , DATEUPD
      FROM (
            SELECT COD_AZIENDA
                 , ARP_FLAG
                 , USERUPD
                 , DATEUPD
                 , ROW_NUMBER() OVER (PARTITION BY COD_AZIENDA ORDER BY DATEUPD DESC NULLS LAST) AS RN
              FROM TGK_FIMA_HISENSE.AW_RUL_DWMCRS_000001
             WHERE ARP_FLAG IS NOT NULL
           )
     WHERE RN = 1
)
/* 日志里最近一次 ARP_FLAG 变更；业务修改人取 USERUPD_NEW（LOG_USER 是数据库会话用户，看不出是谁改的）。 */
, FLIP_ARP AS (
    SELECT COD_AZIENDA
         , ARP_FLAG_OLD
         , ARP_FLAG_NEW
         , USERUPD_NEW
         , DATEUPD_NEW
      FROM (
            SELECT COALESCE(COD_AZIENDA_NEW, COD_AZIENDA_OLD) AS COD_AZIENDA
                 , ARP_FLAG_OLD
                 , ARP_FLAG_NEW
                 , USERUPD_NEW
                 , DATEUPD_NEW
                 , ROW_NUMBER() OVER (PARTITION BY COALESCE(COD_AZIENDA_NEW, COD_AZIENDA_OLD) ORDER BY LOG_TIMESTAMP DESC) AS RN
              FROM TGK_FIMA_HISENSE.AW_RUL_DWMCRS_000001_LOG
             WHERE NVL(ARP_FLAG_NEW, 'ZZZZ') <> NVL(ARP_FLAG_OLD, 'ZZZZ')
           )
     WHERE RN = 1
)
/* 触发器建好之前的 ARP_FLAG 没有日志，这类公司用主表审计字段补修改人和修改时间。 */
SELECT NVL(C.COD_AZIENDA, F.COD_AZIENDA)                             AS COD_AZIENDA   /* 公司 */
     , CASE WHEN C.COD_AZIENDA IS NULL THEN F.ARP_FLAG_NEW ELSE C.ARP_FLAG END AS ARP_FLAG  /* 最新ARP_FLAG，为空表示已清空 */
     , NVL(F.USERUPD_NEW, C.USERUPD)                                 AS USERUPD      /* 修改人 */
     , NVL(F.DATEUPD_NEW, C.DATEUPD)                                 AS DATEUPD      /* 修改时间 */
  FROM CUR_ARP C
  FULL OUTER JOIN FLIP_ARP F
    ON F.COD_AZIENDA = C.COD_AZIENDA
 ORDER BY COD_AZIENDA
