# Tool to clear reset cron job exit status Prometheus metric

## clear_cronjob_exit_status.sh

Usage: <code>clear_cronjob_exit_status.sh &lt;app_instance> &lt;cron_job_name></code>

Set Prometheus metric <code>management_command_exit</code> to zero for given cronjob
within the given application instance

Since it requires $PUSHGATEWAY, copy the script onto a suitable application instance
pod and execute it there.
