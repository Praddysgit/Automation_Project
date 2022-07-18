# Automation_Project
The first part of the script checks if apache is installed on the Ubuntu machine and install it if not present.
It also compresses the generated log files and creates a backup in the s3 bucket.
The second part of the script will schedule a cron job that runs the same script automatically at an interval of 1 day as a root user
