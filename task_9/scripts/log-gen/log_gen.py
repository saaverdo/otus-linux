#!/usr/bin/env python3

from sys import argv
import subprocess
# сколько строк за раз пишем в лог
try:
    LINE_SHIFT = int(argv[1])
    logfile = argv[2]
    outfile = argv[3]
except IndexError:    
    LINE_SHIFT = 5 # default value
    logfile = '/vagrant/syslog.log' # default value
    outfile = '/vagrant/stplog.log' # default value
# logfile - источник лога
# outfile - файл, который будет мониториться сервисом,  в него будет писаться лог порциями

# определим, с какого места читать источник лога
start = subprocess.run(['wc', '-c', outfile],stdout=subprocess.PIPE,
                                            stderr=subprocess.DEVNULL,
                                             encoding='utf-8')
start = 0 if start.returncode else start.stdout.split()[0]

try:
    with open(logfile) as f_i:
        with open(outfile, 'a') as f_o:
            f_i.seek(int(start))
            for i in range(LINE_SHIFT):
                f_o.write(f_i.readline())
except FileNotFoundError as msg:
    print(f"Error {msg}")
