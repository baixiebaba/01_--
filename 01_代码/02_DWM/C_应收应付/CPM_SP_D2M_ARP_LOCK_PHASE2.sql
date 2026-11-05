CREATE OR REPLACE PROCEDURE CPM_SP_D2M_ARP_LOCK_PHASE2(
    P_SCENARIO   IN VARCHAR2
  , P_PERIODO    IN VARCHAR2
  , P_AZIENDA    IN VARCHAR2
  , SESSION_USER IN VARCHAR2
) AS
  /*******************************************************************************
   *                              存储过程说明
   *-----------------------------------------------------------------------------
   * 最后更新时间：20261105 14:07
   * 本次修改：ALTER BY 20261105 14:07 SHIQINGFENG.EX 公司范围改用SESSION_AZIENDA_LIST会话表
   * 上次修改：ALTER BY 20261105 14:00 SHIQINGFENG.EX 新增应收应付二期D2M公司锁定过程
   *
   * 过程名称  ：CPM_SP_D2M_ARP_LOCK_PHASE2
   * 功能描述  ：按场景、期间和会话公司范围将D2M锁定记录的ARP_FLAG更新为Y，并记录更新用户和更新时间
   * 源表      ：TGK_FIMA_HISENSE.V_REF_AZIENDA、TGK_FIMA_HISENSE.AW_RUL_DWMCRS_000001
   * 目标表    ：TGK_FIMA_HISENSE.AW_RUL_DWMCRS_000001
   *
   * 修改历史：
   *   ALTER BY 20261105 14:07 SHIQINGFENG.EX 公司范围改用SESSION_AZIENDA_LIST会话表
   *   ALTER BY 20261105 14:00 SHIQINGFENG.EX 新增应收应付二期D2M公司锁定过程
   *******************************************************************************/
  V_SESSION_ID NUMBER;
BEGIN

  BEGIN
    V_SESSION_ID := SYS_CONTEXT('USERENV', 'SESSIONID');

    DELETE FROM SESSION_AZIENDA_LIST
     WHERE SESSION_ID = V_SESSION_ID;

    DELETE FROM SESSION_V_REF_AZIENDA
     WHERE SESSION_ID = V_SESSION_ID;

    INSERT INTO SESSION_V_REF_AZIENDA(
        SESSION_ID , HIE , NODE , ELEM
    )
    SELECT V_SESSION_ID , HIE , NODE , ELEM
      FROM TGK_FIMA_HISENSE.V_REF_AZIENDA;

    INSERT INTO SESSION_AZIENDA_LIST(
        SESSION_ID , ELEM
    )
    SELECT DISTINCT V_SESSION_ID
         , ELEM
      FROM SESSION_V_REF_AZIENDA
     WHERE SESSION_ID = V_SESSION_ID
       AND HIE = '10'
       AND (
             INSTR(',' || P_AZIENDA || ',', ',' || ELEM || ',') > 0
          OR INSTR(',' || P_AZIENDA || ',', ',' || NODE || ',') > 0
          OR P_AZIENDA = 'ALL'
       );
  END;

  /*
   * 功能：更新参数场景、期间和会话公司范围内的应收应付D2M锁定记录。
   * 输入：P_SCENARIO场景、P_PERIODO期间、SESSION_AZIENDA_LIST公司清单及SESSION_USER更新用户。
   * 输出：ARP_FLAG更新为Y，同时回写USERUPD和DATEUPD；完成后清理当前会话公司数据。
   * 边界：仅处理COD_CONTO为ZAW_D2M_LOCK且ARP_FLAG为N或空的记录；已为Y的记录不更新。
   * ALTER BY 20261105 14:07 SHIQINGFENG.EX 公司范围改用SESSION_AZIENDA_LIST会话表
   */
  BEGIN
    UPDATE TGK_FIMA_HISENSE.AW_RUL_DWMCRS_000001
       SET ARP_FLAG = 'Y'
         , USERUPD = SESSION_USER
         , DATEUPD = SYSDATE
     WHERE COD_SCENARIO = P_SCENARIO
       AND COD_PERIODO = LPAD(P_PERIODO, 2, '0')
       AND COD_AZIENDA IN (
             SELECT ELEM
               FROM SESSION_AZIENDA_LIST
              WHERE SESSION_ID = V_SESSION_ID
       )
       AND COD_CONTO = 'ZAW_D2M_LOCK'
       AND (ARP_FLAG = 'N' OR ARP_FLAG IS NULL)
       
       ;

    DELETE FROM SESSION_AZIENDA_LIST
     WHERE SESSION_ID = V_SESSION_ID;

    DELETE FROM SESSION_V_REF_AZIENDA
     WHERE SESSION_ID = V_SESSION_ID;

    COMMIT;
  END;
END CPM_SP_D2M_ARP_LOCK_PHASE2;
