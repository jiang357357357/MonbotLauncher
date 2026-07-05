const path = require("path");

const projectRoot = path.resolve(__dirname, "../../..");
const appName = process.env.NAPCAT_PM2_NAME || "napcat";
const logRoot = process.env.MON_LOG_ROOT || path.join(projectRoot, "Logs");
const logStartDir = process.env.MON_LOG_START_DIR || path.join(logRoot, "manual");
const processLogDir = path.join(logStartDir, "Process");

module.exports = {
  apps: [
    {
      name: appName,
      cwd: projectRoot,
      script: path.join(projectRoot, "Script/Process/linux/run_napcat.sh"),
      interpreter: "bash",
      autorestart: true,
      max_restarts: 10,
      restart_delay: 3000,
      time: true,
      out_file: path.join(processLogDir, "napcat_process.out.log"),
      error_file: path.join(processLogDir, "napcat_process.err.log"),
      env: {
        NAPCAT_PM2_NAME: appName,
        MON_PROCESS_NAME: appName,
        MON_PROCESS_TAG: "napcat-runtime",
        MON_PROJECT_ROOT: projectRoot,
        MON_LOG_ROOT: logRoot,
        MON_LOG_START_DIR: logStartDir,
      },
    },
  ],
};
