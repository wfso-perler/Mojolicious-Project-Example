#!/usr/bin/perl
use strict;
use warnings;
use utf8;

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/../../lib" }

use Mojo::File qw/path/;
use Mojo::Log;

## pid 文件夹
my $pids = path("pids");
$pids->make_path;

## 日志文件夹
my $logs = path("logs");
$logs->make_path;
my $log_file = $logs->child(__FILE__ . ".log")->to_abs;

my $log = Mojo::Log->new(path => $log_file);

$log->info("#START runing " . __FILE__);

## pid文件
my $pid_file = $pids->child(__FILE__ . ".pid")->to_abs;

## 执行标记，说明程序逻辑是否需要执行
my $execute_flag = 0;

## 如果已经存在pid文件
if(-e $pid_file){
  my $pid = $pid_file->slurp;
  
  ## pid的最后修改时间距现在的时长
  my $mtime = -M $pid_file;
  
  ## 如果pid文件的修改时长已经超过5分钟，则杀死进程，并设置 执行标记 为 1
  if($mtime > 0.0035){
    $log->warn("已有一个活动的主进程（main.pl），运行时间为 $mtime 天，已经超过五分钟没有响应，执行杀死重建操作");
    kill("KILL", $pid);
    $pid_file->remove_tree;
    $execute_flag = 1;
  }
  ## 如果pid文件的修改时长不超过5分钟，则设置 执行标记 为 0
  else{
    $log->warn("已有一个活动的主进程（main.pl），进程id为：$pid，运行时间为：$mtime 天");
    $execute_flag = 0;
  }
}
## 如果不存在 pid文件 则设置 执行标记 为 1
else{
  $execute_flag = 1;
}

## 如果需要执行程序逻辑，则先创建pid文件，并写入进行号
## 待程序逻辑执行完成后删除pid文件
if($execute_flag){
  ## 创建pid文件，并写入进程id
  $pid_file->spurt($$);
  
  
  
  ## ========================================支付处理程序========================================================
  ## 执行 支付处理 程序
  my $payment_process_pid_file = $pids->child("payment_process.pl.pid")->to_abs;
  my $execute_payment_process_flag = 0;
  
  ## 如果存在 pid 文件
  if(-e $payment_process_pid_file){
    my $payment_process_pid = $payment_process_pid_file->slurp;
    
    ## pid文件最后修改时间，距现在的时长，单位为 天
    my $mtime = -M $payment_process_pid_file;
    
    ## 如果 支付处理 程序超过一分钟没有响应，则杀死进程，并设置 执行标记（$execute_payment_process_flag） 为 1
    if($mtime > 0.0007){
      $log->warn("已有一个活动 支付处理（payment_process.pl）进程，运行时间为 $mtime 天，已经超过一分钟没有响应，执行杀死重建操作");
      kill("KILL", $payment_process_pid);
      $payment_process_pid_file->remove_tree;
      $execute_payment_process_flag = 1;
    }
    ## 如果 支付处理 程序响应时间未超过一分钟，设置 执行标记（$execute_payment_process_flag） 为 0
    else{
      $log->info("已有一个活动 支付处理（payment_process.pl） 进程，进程id为：$payment_process_pid，运行时间为：$mtime 天");
      $execute_payment_process_flag = 0;
    }
  }
  ## 如果不存在pid文件，则设置 执行标记（$execute_payment_process_flag） 为 1
  else{
    $log->info("还没有活动的 支付处理（payment_process.pl） 进程，需要启动一个");
    $execute_payment_process_flag = 1;
  }
  
  if($execute_payment_process_flag){
    my $payment_process_pid = fork();
    exec("perl payment_process.pl") unless($payment_process_pid);
    $log->info("启动一个 支付处理（payment_process.pl） 进程 ");
  }
  
  ## ========================================分界线========================================================
  
  ## 删除pid文件
  $pid_file->remove_tree;
}

$log->info("#END runing " . __FILE__);


