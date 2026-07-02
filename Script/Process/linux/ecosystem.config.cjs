const path = require("path");

const projectRoot = path.resolve(__dirname, "../../..");
const appName = process.env.MON_PM2_NAME || "bot";
const processTag = process.env.MON_PROCESS_TAG || "monbot-main";
const serverPort = process.env.MON_SERVER_PORT || "8080";

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
      env: {
        MON_PM2_NAME: appName,
        MON_PROCESS_NAME: appName,
        MON_PROCESS_TAG: processTag,
        MON_SERVER_PORT: serverPort,
        PYTHONUNBUFFERED: "1",
        PYTHONIOENCODING: "utf-8",
        PYTHONUTF8: "1",
      },
    },
  ],
};
