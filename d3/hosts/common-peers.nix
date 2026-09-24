# Shared peer public keys + addresses for Court mesh (fill in real pubs).
# Private keys stay on each host as privateKeyFile paths — never here.
#
# Author: Nikola · D3 example fragment
{
  rig = {
    publicKey = "REPLACE_RIG_PUBLIC_KEY=";
    address = "10.77.0.1";
    endpoint = "rig.example.net:51820"; # set null if no inbound
  };
  controller = {
    publicKey = "REPLACE_CONTROLLER_PUBLIC_KEY=";
    address = "10.77.0.2";
    endpoint = null; # often home/CGNAT — dial out with keepalive
  };
  conduit = {
    publicKey = "REPLACE_CONDUIT_PUBLIC_KEY=";
    address = "10.77.0.3";
    endpoint = "conduit.example.net:51820"; # VPS/public candidate
  };
}
