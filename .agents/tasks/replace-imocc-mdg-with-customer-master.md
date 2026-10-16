# IMOCC 客商大表替换变更说明

## 修改文件

`01_代码/01_DWD/C_应收应付/dwd_fi_mr_ar_imocc_mi.sql`

## 已完成修改

- 新增 `customer_dim` CTE，来源为 `dim.dim_fi_mr_customer_dd`，该表在工作区知识库中登记为“客商主数据表 / 通用客商大表(用户提供)”。
- 使用 `cust_s810_code` 与 IMOCC 来源字段 `a.kunnr` 做关联，双方均使用 `NULLIF(LTRIM(TRIM(...), '0'), '')` 标准化，去除前导零并将空编码转为 NULL。
- 客商名称优先取客商大表 `cust_name`；保留原逻辑中的 S810 `SKAT` 科目文本作为客商大表未匹配时的名称兜底。`SKAT` 不是 MDG 客商主数据或对方公司映射表。
- 国家及一至三级公司分类改为客商大表字段：
  - `country_code`、`country_name`
  - `com_1st_code`、`com_1st_name`
  - `com_2nd_code`、`com_2nd_name`
  - `com_3rd_code`、`com_3rd_name`
- 对方公司改为客商大表字段，并沿用 `dwd_fi_mr_arap_detail_mi.sql` 的优先级：
  - `COALESCE(NULLIF(TRIM(cp_company_mr_code), ''), NULLIF(TRIM(cp_company_code), ''))`
- 删除原 `s810_customer_dim`、`customer_base_dim`、`cp_company_dim` CTE，以及以下旧表依赖：
  - `dw.dwfi_im_td_customer_master_basic_infor`
  - `dw.dim_customer_base_info_dd`
  - `dim.dim_rule_fi_mr_cust2ctp_mapping`
- 未改变金额汇总、ACT 月份过滤、区域/产品逻辑、组织逻辑、利润中心逻辑、目标表字段顺序及最终输出列。
- 文件头已增加 `20261014 MODIFY` 修改记录。

## 与 detail 逻辑的对应关系

`detail` 程序通过 `dim.dim_fi_mr_customer_map_dd` 将 SAP 客商编码映射到统一客商编码，再关联 `dim.dim_fi_mr_customer_dd`，并使用 `COALESCE(c.cp_company_mr_code, c.cp_company_code)` 取得对方公司。

IMOCC 当前来源只提供 S810 客商编码 `kunnr`，没有 SAP 客户端和客商类型。工作区现有 DWS 审计说明也指出，在缺少客户端和客商类型时不能安全关联客商映射表。因此本次直接使用客商大表已提供的 `cust_s810_code` 关联，避免臆造 `cust_sap_client` / `cust_supp_type`，同时复用了 detail 已确认的客商属性和对方公司优先级。

## 验证结果

- 已检查目标 SQL：旧 MDG 客户主数据表、旧 MDG 基础信息表、旧对方公司映射表、旧 CTE 及 `s8/cb/cp` 别名均无剩余引用。
- 已检查目标 SQL：客商大表、`cust_s810_code`、`cust_name`、国家、公司分类和 `cp_company_mr_code/cp_company_code` 均已正确引用。
- 已检查目标 SQL：`customer_dim` 对标准化 S810 编码分组，避免客商大表重复记录造成 IMOCC 金额行复制。
- 已检查最终 SELECT：输出字段仍按原 INSERT 字段清单顺序生成，未调整业务字段和金额字段。
- 未连接数据库，也未执行 `INSERT OVERWRITE`；本次验证为静态 SQL 和文本引用校验。

## 待业务确认项

- 知识库和现有 SQL 能确认 `cust_s810_code` 是客商大表中的 S810 客户编码，但本地无法连接 Doris 验证该列在生产表中的唯一性及历史数据覆盖率。
- `customer_dim` 对同一标准化 S810 编码的属性使用 `MAX` 去重；若客商大表存在同一编码多条有效记录且属性冲突，需要业务确认是否应按 `load_dt` 取最新记录，当前 SQL 未引入未在现有资料中确认的有效期规则。
