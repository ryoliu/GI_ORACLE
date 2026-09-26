# 必要輸入資料

產生可執行的安裝腳本前，必須確認會影響指令正確性的環境資料。不得猜測標示為必要的值。

## 平台與架構

- Linux 發行版本與完整版本號
- CPU 架構
- 確認使用 Oracle Restart，而不是 RAC
- GI Base Software 完整版本
- Database Base Software 完整版本
- 正式環境、UAT、公司環境及客戶環境必須確認 GI RU、DB RU 與 OPatch 版本
- 個人 LAB 的 RU 與 OPatch 可以留空；留空時必須依 [個人環境特別注意事項](personal-environment.md) 略過相關檢查與安裝步驟
- 套件來源為線上 Repository 或離線安裝媒體

## 主機與網路

- Short hostname
- Fully qualified domain name
- 主機 IP
- 名稱解析方式
- Listener 名稱與連接埠
- 額外的 Database Service 與 Domain（如有）

## 帳號與群組

- `grid` 與 `oracle` 使用者名稱
- Oracle Inventory、OSDBA、OSOPER、OSASM、ASMDBA 與 ASMOPER 群組
- 是否有固定 UID 與 GID 的要求

## Oracle 路徑與安裝媒體

- Oracle Inventory 路徑
- Grid Base 與 Grid Home
- Oracle Base 與 Database Home
- Staging 目錄
- GI 與 Database 安裝壓縮檔位置
- 目錄擁有者、群組及容量需求

## ASM 儲存

- 使用 UDEV、ASMLib、ASM Filter Driver 或其他受支援方式
- ASM 磁碟的完整且持久化裝置路徑
- 確認目標磁碟沒有需要保留的資料
- ASM Disk Group 名稱
- 每個 Disk Group 使用的磁碟
- Redundancy 與 Allocation Unit Size
- ASM Instance 與 ASM SPFILE 放置方式
- DATA、FRA 或其他 Disk Group 規劃

不得依磁碟數量自行推測 Redundancy。未取得明確授權時，不得分割磁碟、清除 Header 或建立 ASM Label。

## Database

- Database name
- SID
- DB unique name
- 是否建立 CDB
- PDB name
- Character set 與 National character set
- Memory 配置方式
- DATA 與 FRA 位置
- FRA 大小
- 是否啟用 ARCHIVELOG
- 額外的 Database Service（如有）

## 密碼

必須確認 SYS、SYSTEM、PDBADMIN、ASMSNMP 等密碼的安全輸入方式。不得將密碼寫入 `GI_Setup.conf`、Shell、命令歷史、日誌或版本控制。

## 資料不足時

只詢問目前階段需要的資料。若使用者要求空白範本，可以使用 `CHANGE_ME`，但前置檢查必須拒絕尚未替換的必要值。
