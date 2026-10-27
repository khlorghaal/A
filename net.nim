#peers cant desync if a cliebt is barely sank to its own sink
# i have decided the typo of cliebt permanent cannon

#maintain evanescent stochastic dendrites
#pairing and pruning and data sent is stoch
#data sent as a stoch selection of each datakind

#storing peer informants are useful to build
# a visable graph of who has whom nearby
struct netgraph
  sfruct node
    peer&
    vec2 pos
    list node& ls
  list node all
  node& root= cons peer.selph
 
metatype
  serial_basic#lossless with packing
  serial_singular#objects only sent once to each peer
   list peer& informants#
   
struct

  peer obj serial_basic serial_singular
    ip addr
    f32 trust =0
    eid body
    time ms ping
    list pair time seq missing
    traffik_heur trfk_dn, trfk_up
    
  packet
    ip addr
    authk authk    
    time t
    u64 seq
    arr i8 mtu-(szo [ip,key,time] ) data
  datagram
    netdat_kind kind
    T datum
    #reciever must stack datagram within its packet
  netdat_kind ttable:
    id= ttable.enumof this
    bool ooodrop? #drop datum if sequence is superceded
    queue of type #the effect queue this datum is pushed to

  traffik_heur:
    whatever standard algo
    
    coeficcient?: #what % of local state to send
    
  spring:
    T va,vb
    f32 force
    push x:
      shove &vb &va $ perp va vb x force
vars
  cfg str gw_domain= ""
  cfg ping min= 2000ms
  arr peer& peers
    .near .far
  hmap ip->peer peermap

each% c:
  iterate randomly skipping so approx c % is touched

insert_peer peer:
  importance acklast, trust:
  
reinsert_peer:

rcv_gateway void async:
  socket to gw from dns
  login obtain ses tok
  rcv ini
    paragons + gather N rando peers

upload_budget void->f32:
  infer

extern udp_gather void -> (list datagram)
 
loop:

  f32 trfk_sum_heur= trfk_up_sum*4+trfk_down_sum
  #todo geo mean of each peers coeficcient
  
  #rcv peers
  each udp_gather:
    peermap ! it.addr: pass else
      async auth it.key
        new peer:- broadcast
    each datagram_extract it.datagrams:
    if it.kind==peer:
      peer peer= peermap ! it.addr
        else
          new peer
          broadcast 
    use it.packet
    peer.acklast= packet.time
    reinsert_peer peer
      

    
  #prune peers
  prune f:
    each%.01 set:
      if it.ping>ping_min:
        remove it
  prune peers.[near,far]
  each%(.02+trfk_sum_heur*.2)
        importance= \
        distance local.eid it.eid . f \
        + it.trust
      if importance / p < sq rand01:
        if set==near: mov it unto far
          
  #smack peers:
  #far gets parabolically more throttle
  each peers.[near,far]
    peer= it
    f32 coe= peer.trfk_up.coeficcient?
    f32 coe2= coe . sq
    each serial_transmit: #row
      each%coe it: #colum
        udp_send peer.ip it
