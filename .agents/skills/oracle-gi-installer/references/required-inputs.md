# 必要輸入資料

產生可執行的安裝腳本前，必須確認會影響指令正確性的環境資料。不得猜測標示為必要的值。

## 平台與架構

- Linux 發行版本與完整版本號
- CPU 架構
- 確認使用 Oracle Restart，而不是 RAC
- GI Base Software 完整版本
- Database Base Software 完整版本
- GI RU、DB RU 與 OPatch 的版本及檔案位置
- OS、Oracle Base、RU 與 OPatch 必須構成 Oracle 官方支援的安裝組合
- 個人 LAB 不得略過版本相容性所需的 RU 或 OPatch；Oracle Linux 9 的要求依 [個人環境特別注意事項](personal-environment.md) 處理
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
- Oracle Inventory 群組
- Database OSDBA 群組
- Database OSRACDBA 群組
- ASM OSDBA 群組
- ASM OSASM 群組
- 是否有固定 UID 與 GID 的要求

下列職責分離群組為選用項目：

- Database OSOPER 群組
- ASM OSOPER 群組

使用不同的 `grid` 與 `oracle` owner 時，必須確認下列 primary group 與 secondary group membership：

### Grid owner

- Primary group：Oracle Inventory / OINSTALL
- Secondary group：ASM OSASM
- Secondary group：ASM OSDBA
- Secondary group：每個 Database 的 OSDBA
- Secondary group：每個 Database 的 OSRACDBA
- 啟用 ASM OSOPER 職責分離時，還必須屬於 ASM OSOPER

### Database owner

- Primary group：Oracle Inventory / OINSTALL
- Secondary group：Database OSDBA
- Secondary group：Database OSRACDBA
- Secondary group：ASM OSDBA
- 啟用 Database OSOPER 職責分離時，還必須屬於 Database OSOPER

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
