# SPKeyValueDemo Client Application #
#####################################

This is an application serves as a client for a WAMP server which is a simple key/value store.  The data is visualized using a table view which is bound to the local model of the data using KVO.  The MDWamp client library is used to subscribe to changes in the remote server which affect the local model, and via KVO, automatically update the table view.

For the demo server code, clone btgerst/spkvdemo-server. I suggest simply running the myserver.py script and running the iOS client in the simulator.

To toggle between conventional and Spotify approaches to KVO, change the #if conditional in SPAppDelegate.m -didFinishLaunching method.

Contact the author at brian.gerstle@gmail.com