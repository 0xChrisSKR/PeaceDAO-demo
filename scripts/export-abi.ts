import { promises as fs } from "fs";
import path from "path";

async function main() {
  const rootDir = path.resolve(__dirname, "..");
  const artifactPath = path.join(
    rootDir,
    "artifacts",
    "contracts",
    "PeaceDAO.sol",
    "PeaceDAO.json"
  );

  const frontendDir = path.resolve(
    rootDir,
    "..",
    "PeaceDAO-frontend",
    "src",
    "abi"
  );
  const frontendFilePath = path.join(frontendDir, "PeaceDAO.json");

  let artifactContent: string;
  try {
    artifactContent = await fs.readFile(artifactPath, "utf-8");
  } catch (error) {
    console.error(`Failed to read PeaceDAO artifact at ${artifactPath}`);
    throw error;
  }

  const artifact = JSON.parse(artifactContent);
  const abi = artifact.abi ?? artifact;

  try {
    await fs.access(frontendDir);
  } catch {
    console.warn(
      `PeaceDAO frontend directory not found at ${frontendDir}. Skipping ABI export.`
    );
    return;
  }

  await fs.writeFile(frontendFilePath, JSON.stringify(abi, null, 2), "utf-8");
  console.log(`PeaceDAO ABI exported to ${frontendFilePath}`);
}

main().catch((error) => {
  console.error("Error exporting PeaceDAO ABI:", error);
  process.exit(1);
});
