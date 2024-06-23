[message_processors]
%{ for ip in mp_ip ~}
${ip} 
%{ endfor ~}

[jenkins_slave]
%{ for ip in jk_ip ~}
${ip} 
%{ endfor ~}


