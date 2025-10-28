import { HardhatUserConfig, task } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";
import fs from "fs";
import path from "path";
dotenv.config();

type DeployConfigFile = {
  tokenAddress?: string;
  founderWallet?: string;
  peaceFund?: string;
  daoVaultERC20?: string;
  feeCollector?: string;
  router?: string;
};

function readJson(filePath: string): Record<string, string> {
  if (!fs.existsSync(filePath)) {
    return {};
  }
  try {
    const raw = fs.readFileSync(filePath, "utf8");
    return JSON.parse(raw);
  } catch (err) {
    console.warn(`Could not parse ${filePath}:`, err);
    return {};
  }
}

task("show:config", "Displays the effective PeaceDAO deployment configuration", async () => {
  const root = __dirname;
  const deployConfig = readJson(path.join(root, "deploy_config.json")) as DeployConfigFile;
  const deployments = readJson(path.join(root, "deployments.json"));

  const pick = (
    envKey: string,
    configKey?: keyof DeployConfigFile,
    deploymentKey?: string,
    emptyLabel: string = "(not set)"
  ): string => {
    const envValue = process.env[envKey];
    if (envValue && envValue.trim().length > 0) {
      return envValue;
    }
    if (configKey) {
      const configValue = deployConfig[configKey];
      if (configValue && configValue.trim().length > 0) {
        return configValue;
      }
    }
    if (deploymentKey) {
      const deploymentValue = deployments[deploymentKey];
      if (deploymentValue && deploymentValue.trim().length > 0) {
        return deploymentValue;
      }
    }
    return emptyLabel;
  };

  const rows = [
    { Item: "Founder Wallet", Value: pick("FOUNDER_WALLET", "founderWallet") },
    { Item: "Token Address", Value: pick("TOKEN_ADDRESS", "tokenAddress") },
    {
      Item: "PeaceFund",
      Value: pick("PEACE_FUND_ADDRESS", "peaceFund", "peaceFund", "(not deployed yet)"),
    },
    {
      Item: "DaoVaultERC20",
      Value: pick("DAO_VAULT_ERC20", "daoVaultERC20", "daoVaultERC20", "(not deployed yet)"),
    },
    {
      Item: "FeeCollector",
      Value: pick("FEE_COLLECTOR_ADDRESS", "feeCollector", "feeCollector", "(not deployed yet)"),
    },
    {
      Item: "PeaceGate",
      Value: pick("PEACE_GATE_ADDRESS", "", "peaceGate", "(not deployed yet)"),
    },
    {
      Item: "PeaceDAO",
      Value: pick("PEACE_DAO_ADDRESS", "", "peaceDAO", "(not deployed yet)"),
    },
    {
      Item: "Router",
      Value: pick("UNDERLYING_ROUTER", "router", "router", "(not deployed yet)"),
    },
  ];

  console.log("\nPeaceDAO configuration summary\n");
  console.table(rows);
});

const config: HardhatUserConfig = {
  solidity: "0.8.20",
  networks: {
    bsctest: {
      url: process.env.RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY || "",
  },
};
export default config;
