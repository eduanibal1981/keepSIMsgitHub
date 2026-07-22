module.exports = {
  apps: [
    {
      name: "queue-instant-refill",
      script: "./servers/worker_instant_refill.js",
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'production'
      }
    },
    {
      name: "queue-auto-mini-refill",
      script: "./servers/worker_auto_mini_refill.js",
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'production'
      }
    },
    {
      name: "queue-auto-custom-refill",
      script: "./servers/worker_auto_custom_refill.js",
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'production'
      }
    },
    {
      name: "worker-esim-catalog",
      script: "./servers/worker_esim_catalog.js",
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      watch: false,
      max_memory_restart: '1G',
      env: {
        NODE_ENV: 'production'
      }
    }
  ]
};
