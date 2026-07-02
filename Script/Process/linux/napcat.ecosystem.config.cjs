const path = require("path");

const projectRoot = path.resolve(__dirname, "../../..");
const appName = process.env.NAPCAT_PM2_NAME || "napcat";

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
      env: {
        NAPCAT_PM2_NAME: appName,
        MON_PROCESS_NAME: appName,
        MON_PROCESS_TAG: "napcat-runtime",
      },
    },
  ],
};
