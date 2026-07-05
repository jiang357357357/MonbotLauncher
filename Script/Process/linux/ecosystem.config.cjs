const path = require("path");

const projectRoot = path.resolve(__dirname, "../../..");
const appName = process.env.MON_PM2_NAME || "bot";
const processTag = process.env.MON_PROCESS_TAG || "monbot-main";
const serverPort = process.env.MON_SERVER_PORT || "8080";
const logRoot = process.env.MON_LOG_ROOT || path.join(projectRoot, "Logs");
const logStartDir = process.env.MON_LOG_START_DIR || path.join(logRoot, "manual");
const processLogDir = path.join(logStartDir, "Process");

module.exports = {
  apps: [
    {
      name: appName,
      cwd: projectRoot,
      script: path.join(projectRoot, "Script/Process/linux/run_qqbot.sh"),
      args: "--no-clean",
      interpreter: "bash",
      autorestart: true,
      max_restarts: 10,
      restart_delay: 3000,
      time: true,
      out_file: path.join(processLogDir, "monbot_process.out.log"),
      error_file: path.join(processLogDir, "monbot_process.err.log"),
      env: {
        MON_PM2_NAME: appName,
        MON_PROCESS_NAME: appName,
        MON_PROCESS_TAG: processTag,
        MON_SERVER_PORT: serverPort,
        MON_PROJECT_ROOT: projectRoot,
        MON_LOG_ROOT: logRoot,
        MON_LOG_START_DIR: logStartDir,
        PYTHONUNBUFFERED: "1",
        PYTHONIOENCODING: "utf-8",
        PYTHONUTF8: "1",
      },
    },
  ],
};
