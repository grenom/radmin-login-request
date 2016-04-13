#PowerShell script enables / disables the request to connect to Radmin Server.
#BEFORE USING THE SCRIPT YOU MUST CHANGE THE VARIABLE SETTINGS IN THE HEADER OF THE SCRIPT!!!
#The script can be used locally on the computer with running Radmin Server, 
#remotely via Enter-PSSession/Invoke-command or the AD policy.
#Tested on win8x64, win7x64, win7x86, radmin server v3.5, radmin server v3.4


#logging method 
#0 - to disable logging
#1 - write logs to a file (use together with the $ global: LOGPATH)
#2 - to write logs to the console.
$global:LOG_METOD=1;


#if $global:LOG METHOD=2 then you must specify the path to the file.
$global:LOGPATH="\\host.random.ru\public\radmin_toogle\log\log.txt";


#1 - script will change the key in the registry AskUser 01000000 thereby Radmin Server will request a login request. If the registry value AskUser does not exist it will be created.
#0 - disable the login request to the Radmin Server
$global:on_or_off=1;


#1 - after changing AskUser registry key, rserver3 service will be restarted.
#0 - AskUser after changing a registry key, the service rserver3 not restart.
$global:restart=1;

#########################################################################################
#########################################################################################
#########################################################################################
$global:log_n=0;
$global:date=get-date;
$global:ho=hostname;
$global:arch= Get-WmiObject Win32_Processor; $global:arch=$global:arch.AddressWidth;


function log ($mes) {
    if($global:LOG_METOD -eq 1)
    {
        if ($global:log_n -eq 0) {
            Add-Content $global:LOGPATH -Encoding "UTF8" -Value "########################################################################";
            Add-Content $global:LOGPATH -Encoding "UTF8" -Value "########################################################################";
            Add-Content $global:LOGPATH -Encoding "UTF8" -Value $global:date;
            Add-Content $global:LOGPATH -Encoding "UTF8" -Value $global:ho;
            }
        Add-Content $global:LOGPATH -Encoding "UTF8" -Value $mes;
        $global:log_n++;
    }
    elseif($global:LOG_METOD -eq 2)
    {
        if ($global:log_n -eq 0) {
        write-host "########################################################################";
        write-host "########################################################################";
        write-host $global:date;
        write-host $global:ho;
        }
    write-host $mes;
    $global:log_n++;
    }
}

function myerr ($user_message, $mobj) {
    if(($global:LOG_METOD -eq 1) -or ($global:LOG_METOD -eq 2))
    {
	    if ($mobj) {
	    } else {
	    $temp_err_mes=$error[0].exception.message.tostring();
	    log "ERROR ($user_message): $temp_err_mes";
	    }
    }
}




function check_radmin {
$c=(Get-service Rserver3).Status;
    if($c){
    return 1;
    }
    else {
    return 0;
    }
}


function restart_radmin {
$er=$null;
$t=Get-WmiObject Win32_Service -Filter "Name='rserver3'";
$er=$t.StopService();
myerr "restart_radmin stop" $er;
sleep(5);
$er=$t.StartService();
myerr "restart_radmin start" $er;
return $true;
}


function m_create {
$er=$null;
    if($global:arch -eq 64){
    $er=New-ItemProperty -Path HKLM:\SOFTWARE\Wow6432Node\Radmin\v3.0\Server\Parameters -Name AskUser -Value (00,00,00,00) -PropertyType Binary;
    }
    elseif ($global:arch -eq 32) {
    $er=New-ItemProperty -Path HKLM:\SOFTWARE\Radmin\v3.0\Server\Parameters -Name AskUser -Value (00,00,00,00) -PropertyType Binary;
    }
myerr "m_create" $er;
return $true;
}


function askuser_on {
$r=$null;
    if($global:arch -eq 64){
    $r=Set-ItemProperty -Path HKLM:\SOFTWARE\Wow6432Node\Radmin\v3.0\Server\Parameters -Name AskUser -Value (01,00,00,00) -PassThru;
    }
    elseif ($global:arch -eq 32) {
    $r=Set-ItemProperty -Path HKLM:\SOFTWARE\Radmin\v3.0\Server\Parameters -Name AskUser -Value (01,00,00,00) -PassThru;
    }
myerr "askuser_on" $r;
return $true;
}



function askuser_off {
$r=$null;
    if($global:arch -eq 64){
    $r=Set-ItemProperty -Path HKLM:\SOFTWARE\Wow6432Node\Radmin\v3.0\Server\Parameters -Name AskUser -Value (00,00,00,00) -PassThru;
    }
    elseif ($global:arch -eq 32) {
    $r=Set-ItemProperty -Path HKLM:\SOFTWARE\Radmin\v3.0\Server\Parameters -Name AskUser -Value (00,00,00,00) -PassThru;
    }
myerr "askuser_off" $r;
return $true;
}




function click_stop_rservice {
$s=Get-service Rserver3; 
$s.Stop();
return $true;
}




$status_r=$null;
$r=$null;
if($global:arch){
    $r_check=check_radmin;
        if($r_check -eq 1)
        {
            if($global:arch -eq 64){
            $r=Get-ItemProperty -Path HKLM:\SOFTWARE\Wow6432Node\Radmin\v3.0\Server\Parameters -Name AskUser;
            }
            elseif ($global:arch -eq 32) {
            $r=Get-ItemProperty -Path HKLM:\SOFTWARE\Radmin\v3.0\Server\Parameters -Name AskUser;
            }
        
    
            if($r)
            {
                if($r.AskUser[0] -eq 1)
                {
                    if($global:on_or_off -eq 1)
                    {
                    #log "Request for entry permits already on. I do nothing.";
                    }
                    elseif ($global:on_or_off -eq 0)
                    {
                    log "Off request for entry.";
                    askuser_off;
                        if($global:restart -eq 1)
                        {
                        restart_radmin;
                        }
                    }
                }
                elseif($r.AskUser[0] -eq 0)
                {
                    if($global:on_or_off -eq 1)
                    {
                    log "On request for entry.";
                    askuser_on;
                        if($global:restart -eq 1)
                        {
                        restart_radmin;
                        }
                    }
                    elseif ($global:on_or_off -eq 0)
                    {
                    #log "Request for entry permits already off. I do nothing.";
                    }
                }
                else
                {
                log "correctly set global:on_or_off varible. I do nothing.";
                }
            }
            elseif($error[0].CategoryInfo.Category -ilike "InvalidArgument" -and $error[0].CategoryInfo.TargetName -ilike "AskUser")
            {
                if($global:on_or_off -eq 1)
                {
                log "Key does not exist. Create.";
                m_create;
                askuser_on;
                     if($global:restart -eq 1)
                     {
                     restart_radmin;
                     }
                }
                elseif ($global:on_or_off -eq 0)
                {
                #log "Request for entry permits already off. I do nothing (key does not exist).";
                }
            }
            else 
            {
            myerr "failed registry check" $r;
            }
        }
        else
        {
        myerr "failed service check" $null;
        }
    }
    else
    {
    myerr "failed arch check" $null;
    }