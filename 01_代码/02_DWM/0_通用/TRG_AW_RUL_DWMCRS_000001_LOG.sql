
CREATE OR REPLACE TRIGGER TRG_AW_RUL_DWMCRS_000001_LOG
    AFTER INSERT OR UPDATE OR DELETE
    ON AW_RUL_DWMCRS_000001
    FOR EACH ROW
BEGIN
/*******************************************************************************
 *                                  脚本说明
 *-----------------------------------------------------------------------------
 * 最后更新时间：20261105 15:33
 * 本次修改：ALTER BY 20261105 15:33 SHIQINGFENG.EX 新增 ARP_FLAG 新旧值日志监控。
 *
 * 脚本名称  ：TRG_AW_RUL_DWMCRS_000001_LOG.sql
 * 功能描述  ：记录 AW_RUL_DWMCRS_000001 数据新增、修改和删除前后的字段值。
 * 源表      ：AW_RUL_DWMCRS_000001
 * 目标表    ：AW_RUL_DWMCRS_000001_LOG
 *
 * 修改历史：
 *   ALTER BY 20261105 15:33 SHIQINGFENG.EX 新增 ARP_FLAG 新旧值日志监控。
 ******************************************************************************/
    CASE
        -- ===== INSERT：只有新值，旧值全NULL =====
        WHEN INSERTING THEN
            INSERT INTO AW_RUL_DWMCRS_000001_LOG (
                LOG_ACTION,
                LOG_TIMESTAMP,
                LOG_USER,
                OID_NEW,          COD_AZIENDA_NEW,  SAP_CLIENT_NEW,
                VALID_FR_NEW,     VALID_TO_NEW,     REV_FLAG_NEW,
                SAE_FLAG_NEW,     GAE_FLAG_NEW,     RDE_FLAG_NEW,
                OPL01_FLAG_NEW,   OPL02_FLAG_NEW,   PROVENIENZA_NEW,
                USERUPD_NEW,      DATEUPD_NEW,      EN_VERSION_NEW,
                COD_CONTO_NEW,    D_BG_NEW,         COD_SCENARIO_NEW,
                COD_PERIODO_NEW,  KPICALC_FLAG_NEW, REV02_FLAG_NEW,
                REV03_FLAG_NEW,   REV04_FLAG_NEW,   REV05_FLAG_NEW,
                REV01_FLAG_NEW,    ARP_FLAG_NEW,     FACTORY, FACPRO_FLAG
            ) VALUES (
                'INSERT', SYSDATE, USER,
                :NEW.OID,          :NEW.COD_AZIENDA,  :NEW.SAP_CLIENT,
                :NEW.VALID_FR,     :NEW.VALID_TO,     :NEW.REV_FLAG,
                :NEW.SAE_FLAG,     :NEW.GAE_FLAG,     :NEW.RDE_FLAG,
                :NEW.OPL01_FLAG,   :NEW.OPL02_FLAG,   :NEW.PROVENIENZA,
                :NEW.USERUPD,      :NEW.DATEUPD,      :NEW.EN_VERSION,
                :NEW.COD_CONTO,    :NEW.D_BG,         :NEW.COD_SCENARIO,
                :NEW.COD_PERIODO,  :NEW.KPICALC_FLAG, :NEW.REV02_FLAG,
                :NEW.REV03_FLAG,   :NEW.REV04_FLAG,   :NEW.REV05_FLAG,
                :NEW.REV01_FLAG,   :NEW.ARP_FLAG,     :NEW.FACTORY, :NEW.FACPRO_FLAG
            );

        -- ===== UPDATE：新旧值都记录 =====
        WHEN UPDATING THEN
            INSERT INTO AW_RUL_DWMCRS_000001_LOG (
                LOG_ACTION,
                LOG_TIMESTAMP,
                LOG_USER,
                OID_NEW,          COD_AZIENDA_NEW,  SAP_CLIENT_NEW,
                VALID_FR_NEW,     VALID_TO_NEW,     REV_FLAG_NEW,
                SAE_FLAG_NEW,     GAE_FLAG_NEW,     RDE_FLAG_NEW,
                OPL01_FLAG_NEW,   OPL02_FLAG_NEW,   PROVENIENZA_NEW,
                USERUPD_NEW,      DATEUPD_NEW,      EN_VERSION_NEW,
                COD_CONTO_NEW,    D_BG_NEW,         COD_SCENARIO_NEW,
                COD_PERIODO_NEW,  KPICALC_FLAG_NEW, REV02_FLAG_NEW,
                REV03_FLAG_NEW,   REV04_FLAG_NEW,   REV05_FLAG_NEW,
                REV01_FLAG_NEW,    ARP_FLAG_NEW,
                OID_OLD,          COD_AZIENDA_OLD,  SAP_CLIENT_OLD,
                VALID_FR_OLD,     VALID_TO_OLD,     REV_FLAG_OLD,
                SAE_FLAG_OLD,     GAE_FLAG_OLD,     RDE_FLAG_OLD,
                OPL01_FLAG_OLD,   OPL02_FLAG_OLD,   PROVENIENZA_OLD,
                USERUPD_OLD,      DATEUPD_OLD,      EN_VERSION_OLD,
                COD_CONTO_OLD,    D_BG_OLD,         COD_SCENARIO_OLD,
                COD_PERIODO_OLD,  KPICALC_FLAG_OLD, REV02_FLAG_OLD,
                REV03_FLAG_OLD,   REV04_FLAG_OLD,   REV05_FLAG_OLD,
                REV01_FLAG_OLD,    ARP_FLAG_OLD,     FACTORY, FACPRO_FLAG
            ) VALUES (
                'UPDATE', SYSDATE, USER,
                :NEW.OID,          :NEW.COD_AZIENDA,  :NEW.SAP_CLIENT,
                :NEW.VALID_FR,     :NEW.VALID_TO,     :NEW.REV_FLAG,
                :NEW.SAE_FLAG,     :NEW.GAE_FLAG,     :NEW.RDE_FLAG,
                :NEW.OPL01_FLAG,   :NEW.OPL02_FLAG,   :NEW.PROVENIENZA,
                :NEW.USERUPD,      :NEW.DATEUPD,      :NEW.EN_VERSION,
                :NEW.COD_CONTO,    :NEW.D_BG,         :NEW.COD_SCENARIO,
                :NEW.COD_PERIODO,  :NEW.KPICALC_FLAG, :NEW.REV02_FLAG,
                :NEW.REV03_FLAG,   :NEW.REV04_FLAG,   :NEW.REV05_FLAG,
                :NEW.REV01_FLAG,   :NEW.ARP_FLAG,
                :OLD.OID,          :OLD.COD_AZIENDA,  :OLD.SAP_CLIENT,
                :OLD.VALID_FR,     :OLD.VALID_TO,     :OLD.REV_FLAG,
                :OLD.SAE_FLAG,     :OLD.GAE_FLAG,     :OLD.RDE_FLAG,
                :OLD.OPL01_FLAG,   :OLD.OPL02_FLAG,   :OLD.PROVENIENZA,
                :OLD.USERUPD,      :OLD.DATEUPD,      :OLD.EN_VERSION,
                :OLD.COD_CONTO,    :OLD.D_BG,         :OLD.COD_SCENARIO,
                :OLD.COD_PERIODO,  :OLD.KPICALC_FLAG, :OLD.REV02_FLAG,
                :OLD.REV03_FLAG,   :OLD.REV04_FLAG,   :OLD.REV05_FLAG,
                :OLD.REV01_FLAG,   :OLD.ARP_FLAG,     :OLD.FACTORY, :OLD.FACPRO_FLAG
            );

        -- ===== DELETE：只有旧值，新值全NULL =====
        WHEN DELETING THEN
            INSERT INTO AW_RUL_DWMCRS_000001_LOG (
                LOG_ACTION,
                LOG_TIMESTAMP,
                LOG_USER,
                OID_OLD,          COD_AZIENDA_OLD,  SAP_CLIENT_OLD,
                VALID_FR_OLD,     VALID_TO_OLD,     REV_FLAG_OLD,
                SAE_FLAG_OLD,     GAE_FLAG_OLD,     RDE_FLAG_OLD,
                OPL01_FLAG_OLD,   OPL02_FLAG_OLD,   PROVENIENZA_OLD,
                USERUPD_OLD,      DATEUPD_OLD,      EN_VERSION_OLD,
                COD_CONTO_OLD,    D_BG_OLD,         COD_SCENARIO_OLD,
                COD_PERIODO_OLD,  KPICALC_FLAG_OLD, REV02_FLAG_OLD,
                REV03_FLAG_OLD,   REV04_FLAG_OLD,   REV05_FLAG_OLD,
                REV01_FLAG_OLD,    ARP_FLAG_OLD,     FACTORY, FACPRO_FLAG
            ) VALUES (
                'DELETE', SYSDATE, USER,
                :OLD.OID,          :OLD.COD_AZIENDA,  :OLD.SAP_CLIENT,
                :OLD.VALID_FR,     :OLD.VALID_TO,     :OLD.REV_FLAG,
                :OLD.SAE_FLAG,     :OLD.GAE_FLAG,     :OLD.RDE_FLAG,
                :OLD.OPL01_FLAG,   :OLD.OPL02_FLAG,   :OLD.PROVENIENZA,
                :OLD.USERUPD,      :OLD.DATEUPD,      :OLD.EN_VERSION,
                :OLD.COD_CONTO,    :OLD.D_BG,         :OLD.COD_SCENARIO,
                :OLD.COD_PERIODO,  :OLD.KPICALC_FLAG, :OLD.REV02_FLAG,
                :OLD.REV03_FLAG,   :OLD.REV04_FLAG,   :OLD.REV05_FLAG,
                :OLD.REV01_FLAG,   :OLD.ARP_FLAG,     :OLD.FACTORY, :OLD.FACPRO_FLAG
            );
    END CASE;
END;
