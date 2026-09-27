# 安裝後檢查清單

本清單是整套 Oracle GI、Oracle Restart、ASM、Listener 與 Database 安裝流程的最終驗收清單，不代表所有項目都由 `09_PostCheck.sh` 重新執行。

- Oracle Restart、OHAS、CRS、ASM 與 Disk Group 由 `03_ConfigGI.sh` 驗證。
- Listener 與 Endpoint 由 `05_CreateListener.sh` 驗證。
- Database、PDB、Service、ARCHIVELOG、FRA 與連線狀態由 `09_PostCheck.sh` 驗證。
- 最終驗收應彙整各階段結果，不得讓 `09_PostCheck.sh` 切換成 `root` 或 `grid` 重跑其他 owner 的檢查。

- [ ] Oracle Restart 服務正常
- [ ] OHAS 與 CRS 資源狀態正常
- [ ] ASM Instance 正常啟動
- [ ] 所有 ASM Disk Group 已掛載且容量正常
- [ ] Listener 狀態與 Endpoint 正確
- [ ] Database 已註冊至 Oracle Restart
- [ ] Database Open Mode 正確
- [ ] 所有指定 PDB 狀態正確
- [ ] Database Service 已註冊且可用
- [ ] Local SQL 連線成功
- [ ] Oracle Net 連線成功
- [ ] ARCHIVELOG 設定符合需求
- [ ] FRA 位置與大小符合需求
- [ ] Grid、ASM、Listener 與 Database 的自動啟動策略正確
- [ ] 重新檢查安裝日誌，沒有未處理的錯誤
- [ ] 已保存最終設定、版本及檢查結果
