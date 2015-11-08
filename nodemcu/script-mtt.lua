identity="winkekatze-"..node.chipid()
print("id:"..identity)

-- BROKER="m2m.eclipse.org"
BROKER="mqtt.kgbvax.net"
-- BROKER="broker.hivemq.com"
BRPORT=1883 -- TCP wihtout TLS
BRUSER=""
BRPWD="" 

PWM_freq = 50 --Hz
-- IOMap https://github.com/nodemcu/nodemcu-firmware/wiki/nodemcu_api_en#new_gpio_map
servo1_pin=4 -- GPIO2
led_pin=1 -- GPIO5

seek_delay=30000 --usec
servo_max=35
servo_min=120
servo_idle=55

pwm.setup(servo1_pin,PWM_freq,0)
pwm.setup(led_pin,PWM_freq,0)

MYTOPIC="/warpzone.ms/winkekatze" --base 
mytopic_out=MYTOPIC .. "/%winkekatze"  -- 
mytopic_msg=MYTOPIC .. "/%winkekatze/messages" --
mytopic_eval=MYTOPIC .. "/eval"


servo_paw_low=35
servo_paw_high=120
paw_idle_value=0

--move to paw to position 0..99 (0 being top)
function paw(val) 
  local val=servo_paw_low+(servo_paw_high-servo_paw_low)*val/100
  --print("v pwm " .. val)
  pwm.setduty(servo1_pin,val)
  --tmr.wdclr()
end

function paw_idle()
  paw(paw_idle_value)
end

function paw_busy()
end


-- IRC Bridge
--Client mosqsub/55267-kgbvx.fri received PUBLISH (d0, q0, r1, m0, '/warpzone/winkekatze2/%ffms/topic', ... (118 bytes))

-- wait for ip
function waitForIp()
  local ip 
  repeat
    tmr.delay(10000)
    ip =wifi.sta.getip()
  until ip ~= nil   
  print("ip: "..ip)
end

waitForIp() -- wait for IP 
waitForIp=nil -- and forget the function

-- initiate the mqtt client and set keepalive timer to 120sec
m = mqtt.Client(myname, 120,BRUSER,BRPWD)

m:on("connect", function(con) NET=true print ("connected") end)
m:on("offline", function(con) NET=false print ("offline") end)

function helpStr(act) 
  local help = "I can do: "
  if act then
    for key,value in pairs(act) do 
      help= help .. "'" .. key .."'" .. " " 
    end
    return help
  end
  return "No actions available."
end


function say(what)
  print(what)
  m:publish(mytopic_out, what,0,0)
end

-- on receive message
m:on("message", function(conn, topic, data)
    if data ~= nil then
      action=nil 
      if (topic == mytopic_msg) then
        for key,value in pairs(actions) do --see whether text contains an action
          if data:find(key) ~= nil then
            action=value
            actionName=key
          end
        end
        if action ~= nil then
          pcall(action,data)
          if error ~= nil then
            say("I did: " .. actionName)
          else
            say(error)
          end
        else
          -- say("I don't know how to do: " .. "'".. data .. "'. " .. help)
        end
      else if (topic == mytopic_eval) then
        print("eval: ".. data)
        local f,err=loadstring(data)
        if not f then
          say(err)
        else
        local res,err=pcall(f)
        if res then
          say("err:" .. tostring(err))
        end
      end
    end
  end
end
end)

m:connect(BROKER, BRPORT, 0, 
  function(conn) 
    print("connect:")
    -- subscribe topic with qos = 0
    m:subscribe(mytopic_msg,0, 
      function(conn) 
        say("Die Katze ist erwacht.")
        intro()
      end)
    m:subscribe(mytopic_eval,0)
  end) 

function intro() 
  --say("Ich bin Katze.")
  say("MQTT: ".. BROKER .. " topic:" .. mytopic_msg)
  say(helpStr(actions))
  tmr.alarm(0,2400000,0,intro)
end
