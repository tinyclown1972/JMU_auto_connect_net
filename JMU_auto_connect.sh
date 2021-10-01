#!/bin/sh
export netok=0
export okflag=0

#cron配置示例，删除前面的#粘贴即可
#每十分钟检测一次
#*/10 * * * * /bin/sh /usr/code/check_net.sh > /usr/code/blank_temp.log 2>&1 &
#晚上23：05分检测一次，快速恢复网络
# 5 23 * * * /bin/sh /usr/code/check_net.sh > /usr/code/blank_temp.log 2>&1 &
#晚上23：08分检测一次，快速恢复网络，有时候断网比较慢，可能5分没有断
# 8 23 * * * /bin/sh /usr/code/check_net.sh > /usr/code/blank_temp.log 2>&1 &
#早上6：15强制断网，防止白天仍然使用校园网，而不是运营商网络
# 15 6 * * * jmusupplicant -k
#早上强制刷新一下网口，防止不断连
#17 6 * * * ifup wan

#每一项都必须配置
#用户需自行配置
account1=""					#主账户，使用ISP_num的账户	
account2=""					#副账户，主账户失效时切换使用
password1=""				#主账户密码
password2=""				#副账户密码
interface_card_num="eth1"	#当前机器的网口
ISP_num=""					#当前主账户的ISP提供商 0为校园网 1为联通网 2为移动网
night_mode_ip1=""	#夜间上网 伪造IP地址，获取该ip方式可以去夜间能够认证的地方连接一下校园网，直接抄ip
night_mode_ip2="" #夜间上网 伪造IP地址

#可以不配置，使用默认配置
interface_card_num1="wan"	#需要重启的网络接口
pingcount=3 			#每次进行网络连通性测试多少次，次数多稳定耗时长，反而反之
pingip1="202.108.22.5" 		#测试网络连通性的ip1 BAIDU
shutethdur=2 			#关闭网口后暂停时间 单位S
afterethdur=10 			#重启网口后暂停时间，避免晚间无法启用midnight模式 单位S
LogMax=32			#最大log容量，超过时会进行清空 当前为32KB
LogFile="/usr/code/check.log"	#log存放路径
blank_temp_log="/usr/code/blank_temp.log" #用于逆置log的暂存文件

echo "--------------------"
echo "Start test net : $(date +%Y%m%d%H%M)"

function LogTextCall()
{
	if [ ! -f "$1" ]; then
		echo "Log State:Create Log"
	else
		Size=`ls -l $1 | awk '{ print $5 }'`
		Max=$((1024*$2))
		if [ $Size -ge $Max ]; then
			cat /dev/null > $1
			echo "Log State:Clear Log"
		else
			echo "State:Log Byte $Size/$Max"
		fi
	fi 
}

#进行log查询，判断是否超过最大限制，超过即清空
LogTextCall $LogFile $LogMax

#开始第一次进行网络连通性测试
echo "Start first time ping"
PING=`ping -c $pingcount $pingip1|grep -v grep|grep '64 bytes' |wc -l`
if [ ${PING} -ne 0 ];then
	echo "Net OK!"
	netok=1
else
	echo "Net Error!"
	netok=0
fi

#当网络测试失败时进行再一次尝试，防止是因为第一次的pingip不通所导致的误判，所以建议pingip1具有很高的稳定性
#仍然ping根据时间段则尝试重连
if [ $netok -eq $okflag ];then
	echo "Start second time ping"
	PING=`ping -c $pingcount $pingip1|grep -v grep|grep '64 bytes' |wc -l`
	if [ ${PING} -ne 0 ];then                                                                      
		echo "Reping succeed!"
		netok=1                                                                                 
	else
		time=$(date +%H)    
		if [[ $time -ge 0 ]] && [[ $time -lt 6 ]];then
			echo "Try night mode with usr $account1"
			jmusupplicant -k
			ifdown $interface_card_num1
			sleep $shutethdur
			ifup $interface_card_num1
			sleep $afterethdur
			jmusupplicant -u $account1 -p $password1 -s 0 -b -n --ip $night_mode_ip1 --interface_card $interface_card_num
		elif [[ $time -ge 23 ]] && [[ $time -le 24 ]];then
			echo "Try night mode with usr $account1"
			jmusupplicant -k
        		ifdown $interface_card_num1
			sleep $shutethdur
			ifup $interface_card_num1
			sleep $afterethdur
			jmusupplicant -u $account1 -p $password1 -s 0 -b -n --ip $night_mode_ip1 --interface_card $interface_card_num
		else
			echo "Try first reconnect in daytime"
			jmusupplicant -k
			ifdown $interface_card_num1
			sleep $shutethdur
			ifup $interface_card_num1
			sleep $afterethdur
			jmusupplicant -u $account1 -p $password1 -s $ISP_num -b --interface_card $interface_card_num
		fi                                                                               
	fi
fi

#经过第一次重连后，测试网络连通性，若仍然不通，根据时间段再次尝试重连
if [ $netok -eq $okflag ];then
	echo "Start third time ping"
	PING=`ping -c $pingcount $pingip1|grep -v grep|grep '64 bytes' |wc -l`
	if [ ${PING} -ne 0 ];then                                                                      
        	echo "Reconnect succeed!"                                                          
      		netok=1                                                                                 
	else                                                                                     
        	echo "Reconnect failure!"
        	time=$(date +%H)    
		if [[ $time -ge 0 ]] && [[ $time -lt 6 ]];then
			echo "Try night mode with usr $account2"
			jmusupplicant -k
			ifdown $interface_card_num1
			sleep $shutethdur
			ifup $interface_card_num1
			sleep $afterethdur
			jmusupplicant -u $account2 -p $password2 -s 0 -b -n --ip $night_mode_ip2 --interface_card $interface_card_num
		elif [[ $time -ge 23 ]] && [[ $time -le 24 ]];then
			echo "Try night mode with usr $account1"
			jmusupplicant -k
        		ifdown $interface_card_num1
			sleep $shutethdur
			ifup $interface_card_num1
			sleep $afterethdur
			jmusupplicant -u $account2 -p $password2 -s 0 -b -n --ip $night_mode_ip2 --interface_card $interface_card_num
		else
			echo "Try second reconnect in daytime"
			jmusupplicant -k
			ifdown $interface_card_num1
			sleep $shutethdur
			ifup $interface_card_num1
			sleep $afterethdur
			jmusupplicant -u $account1 -p $password1 -s $ISP_num -b --interface_card $interface_card_num
		fi
    fi
fi

#最后测试下有没有连上，
if [ $netok -eq $okflag ];then
	echo "Start last time try ping"
	PING=`ping -c $pingcount $pingip1|grep -v grep|grep '64 bytes' |wc -l`
	if [ ${PING} -ne 0 ];then                                                                      
        	echo "Reconnect succeed!"                                                          
      		netok=1                                                                                 
	else                                                                                     
        	echo "Reconnect failure! Kill the process"
        	jmusupplicant -k
    fi
fi

echo --------------------
cat $LogFile >> $blank_temp_log                                                                   
cat $blank_temp_log > $LogFile
cat /dev/null > $blank_temp_log