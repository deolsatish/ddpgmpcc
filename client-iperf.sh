t=100

runtime="100 seconds"

for j in {1..3}  
do  
        for b in {375000,400000,550000,700000,850000,1000000}
        do
                bm=`expr $b \* 1024`

                for i in {reno,pcc,balia,bbr,lia,olia,wvegas,pcc_loss}
                do
                        echo "$j" | tr '\n' ',' >>  results-trial.txt
                        echo "$i" | tr '\n' ',' >>  results-trial.txt
                        echo "$b" | tr '\n' ',' >>  results-trial.txt

                        endtime=$(date -ud "$runtime" +%s)

                        sudo ssh router1 -f sudo tc qdisc replace dev enp6s0f1 parent 1:3 handle 3: bfifo limit $bm

                        sudo ssh router2 -f sudo tc qdisc replace dev enp6s0f0 parent 1:3 handle 3: bfifo limit $bm

                        sudo sysctl -w net.ipv4.tcp_congestion_control=$i

                        if [[ "$i" == "bbr" ]]
                        then
                                sudo sysctl -w net.mptcp.mptcp_scheduler=default_pacing
                        elif [[ "$i" == "pcc" ]]
                        then
                                sudo sysctl -w net.mptcp.mptcp_scheduler=default_pacing
                        elif [[ "$i" == "pcc_loss" ]]
                        then
                                sudo sysctl -w net.mptcp.mptcp_scheduler=default_pacing
                        else
                                sudo sysctl -w net.mptcp.mptcp_scheduler=default
                        fi



                        iperf3 -f m -c 192.168.3.1 -p 5101 -C "$i" -P 1 -i 0.1 -t $t | ts '%.s' | tee $i-$j-$b-trial-iperf.txt > /dev/null & rm -f $i-$j-$b-trial-ss.txt 2>&1 & 
                        iperf3 -f m -c 192.168.3.1 -p 5102 -C "reno" -P 1 -i 0.1 -t $t | ts '%.s' | tee $i-$j-$b-trial-iperf1.txt > /dev/null 2>&1 & 
                        
                        while [[ $(date -u +%s) -le $endtime ]]; do ss --no-header -eipn dst 192.168.3.1 or dst 192.168.4.1 | ts '%.s' | tee -a $i-$j-$b-trial-ss.txt > /dev/null;sleep 0.1; done
                        sleep $t;
                        cat $i-$j-$b-trial-iperf.txt | grep "sender" | awk '{print $8}' | tr '\n' ',' >> results-trial.txt
                        sed '/fd=3/d' $i-$j-$b-trial-ss.txt > $i-$j-$b-trial-ss1.txt
                        cat $i-$j-$b-trial-ss1.txt | sed -e ':a; /<->$/ { N; s/<->\n//; ba; }'  | grep "iperf3" > $i-$j-$b-trial-ss-processed.txt
                        cat $i-$j-$b-trial-ss-processed.txt | grep -oP '\brtt:.*?(\s|$)' |  awk -F '[:,]' '{print $2}' | tr -d ' '  | cut -d '/' -f 1   > srtt-$i-$j-$b-trial.txt
                        awk '{ total += $1; count++ } END { print total/count }' srtt-$i-$j-$b-trial.txt >> results-trial.txt;
                        

                done
        done
done 
