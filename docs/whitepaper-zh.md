# PeaceDAO 捐款分潤（社群經理更新）

## 角色定位
- **驗證者**：審核捐款證明是否可信，每筆撥款可獲得極小比例獎勵。
- **社群經理**：由 DAO 提案任命，需質押 **≥ 500,000 枚 $世界和平**，同時最多 **3 人**。
- **營運 (Founder)**：領取扣除獎勵後的剩餘營運經費。
- **受益人**：固定取得 **90%** 的捐款金額。

## 質押與任期
- 任命前必須持有並質押至少 **500,000 $世界和平**。
- 質押金會鎖定至任期結束，DAO 移除後才可領回。
- 任免流程必須透過 DAO 提案執行，最大人數受 PeaceFund 部署參數限制。

## 捐款分配公式
對捐款金額 `D`：
1. 受益人：`beneficiary = D * 90%`
2. 營運池：`ops = D * 10%`
3. 驗證者獎勵：`verifierReward = D * 0.005%`
4. 社群經理獎勵池：`managerPool = D * 0.005%`
5. 營運剩餘：`opsRemainder = ops - verifierReward - managerPool`

`managerPool` 會平均分配給所有在職經理；若因四捨五入產生的零碎金額，將回流營運池。

### 範例（100 BNB 捐款，2 位經理）
- 受益人：`90.0000 BNB`
- 驗證者：`0.0050 BNB`
- 經理：`0.0050 BNB` → 每人 `0.0025 BNB`
- 營運：`9.9900 BNB`

## 合約流程
- `PeaceFund.executeApprovedDonation` 完成所有分潤並發出 `DonationExecuted` 事件。
- `PeaceDAO.appointManagers/removeManagers` 維護名單與質押，同步有效經理到金庫。
- `PeaceVerify.submitVerification` 回報驗證者地址，讓金庫能正確發獎。
