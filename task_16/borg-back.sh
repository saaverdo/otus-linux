#!/bin/bash
# Client and server name
BACKUP_USER=back_oper
BACKUP_HOST=backup-server
# Backup type, it may be data, system, mysql, binlogs, etc.
TYPEOFBACKUP="etc"
REPOSITORY=$BACKUP_USER@$BACKUP_HOST:/var/backup/$(hostname)
# Backup
borg create -v --stats $REPOSITORY::$TYPEOFBACKUP-$(date +%Y-%m-%d-%H-%M) /${TYPEOFBACKUP}
# Clear old backups
borg prune \
  -v --list \
  ${REPOSITORY} \
  --keep-daily=90 \
  --keep-monthly=9