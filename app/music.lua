-- Music search and playback engine based on the supplied player (API v2.1).
-- The controller owns the queue; audio nodes fetch the selected stream locally.
local M = {}
M.API = "https://ipod-2to6magyna-uc.a.run.app/"
M.VERSION = "2.1"

function M.new(config, network)
  local saved={}
  if fs and fs.exists("/goober/data/playlists.json") then
    local h=fs.open("/goober/data/playlists.json","r")
    if h then local ok,v=pcall(textutils.unserialiseJSON,h.readAll()); h.close(); if ok and type(v)=="table" then saved=v end end
  end
  return setmetatable({ config=config, network=network, query="", results={}, queue={}, current=nil,
    status="Stopped", error=nil, speakers={}, decoder=nil, playing=false, saved={},
    handle=nil, decoder=nil, pending=nil, playingId=nil, saved=saved, streamSequence=0,
    receiveQueue={}, receivedTrack=nil, expectedSequence=0 }, {__index=M})
end

function M:savePlaylist(name, tracks)
  name=tostring(name or ""):gsub("[%c]",""):sub(1,32)
  if name=="" or type(tracks)~="table" or #tracks==0 then return false,"name and search results required" end
  self.saved[name]=tracks
  fs.makeDir("/goober/data")
  local h,err=fs.open("/goober/data/playlists.json","w")
  if not h then return false,err end
  h.write(textutils.serialiseJSON(self.saved)); h.close(); return true
end

function M:search(query)
  self.query=query or ""
  if self.query=="" then self.error="Enter a search or video/playlist URL"; return false end
  if not http or not http.get then self.error="HTTP is disabled"; return false end
  local url=M.API.."?v="..M.VERSION.."&search="..textutils.urlEncode(self.query)
  local ok,h,err=pcall(http.get,url)
  if not ok or not h then self.error=tostring(err or h or "Search request failed"); return false end
  local body=h.readAll(); h.close()
  local parsedOk,data=pcall(textutils.unserialiseJSON,body)
  if not parsedOk or type(data)~="table" then self.error="Music service returned invalid results"; return false end
  self.results=data.results or data
  self.error=nil
  return true
end

function M:enqueue(track, playNow)
  if type(track)~="table" then return false end
  if playNow then self:stopLocal(); self.current=track; self.playing=true; if self.network.role=="controller" then self:beginLocal() end else table.insert(self.queue,track) end
  self.status=playNow and "Requested" or "Queued"
  self:publish(playNow and "play" or "enqueue", track)
  return true
end

function M:publish(kind,track)
  local value=kind=="volume" and self.config.music.volume or kind=="loop" and self.config.music.loop or nil
  local payload={action=kind,track=track,current=self.current,queue=self.queue,playing=self.playing,volume=self.config.music.volume,loop=self.config.music.loop,value=value}
  if self.network.sendMusic then self.network:sendMusic(payload) end
end

function M:stopLocal()
  if self.handle then pcall(self.handle.close); self.handle=nil end
  for _,s in ipairs(peripheral.find("speaker") or {}) do pcall(s.stop) end
  self.playingId=nil; self.pending=nil
end

function M:beginLocal()
  if not self.current or not self.current.id then self.error="Track has no playable ID"; self.status="Unavailable"; return end
  if not http or not http.get then self.error="HTTP is disabled"; self.status="Unavailable"; return end
  local url=M.API.."?v="..M.VERSION.."&id="..textutils.urlEncode(tostring(self.current.id))
  local ok,h,err=pcall(http.get,url,nil,true)
  if not ok or not h then self.error=tostring(err or h or "Stream request failed"); self.status="Stream error"; self.playing=false; return end
  local audio=peripheral.find("speaker")
  if self.network.role~="controller" and not audio then h.close(); self.error="No speaker attached to this audio node"; self.status="No speaker"; self.playing=false; return end
  self.handle=h; self.decoder=require("cc.audio.dfpwm").make_decoder(); self.playingId=self.current.id; self.status="Playing"; self.error=nil
  self.streamSequence=0
  if self.network.role=="controller" then self:publish("play",self.current) end
end

function M:onAudioEmpty()
  self.pending=true
end

function M:step()
  if not self.playing then return end
  if not self.handle then self:beginLocal(); return end
  if self.pending==false then return end
  local ok,chunk=pcall(self.handle.read,16*1024)
  if not ok then self.error=tostring(chunk); self:stopLocal(); self.playing=false; self.status="Stream error"; return end
  if not chunk then
    self:stopLocal()
    if #self.queue>0 then self.current=table.remove(self.queue,1); self:beginLocal()
    elseif self.config.music.loop=="song" and self.current then self:beginLocal()
    elseif self.config.music.loop=="queue" and self.current then table.insert(self.queue,self.current); self.current=table.remove(self.queue,1); self:beginLocal()
    else self.playing=false; self.status="Stopped"; if self.network.role=="controller" then self:publish("stop") end end
    return
  end
  local samples=self.decoder(chunk)
  if self.network.role=="controller" and self.network.broadcastAudio then
    self.streamSequence=self.streamSequence+1
    self.network:broadcastAudio(self.playingId,self.streamSequence,chunk)
  end
  self.pending=false
  if self.network.role=="controller" then self.pending=true; return end
  for _,s in ipairs(peripheral.find("speaker") or {}) do
    local good,accepted=pcall(s.playAudio,s,samples,self.config.music.volume)
    if good and accepted then self.pending=true end
  end
end

function M:onAudioChunk(payload)
  if type(payload)~="table" or type(payload.data)~="string" or type(payload.track_id)~="string" then return end
  if self.receivedTrack~=payload.track_id then
    self:stopLocal(); self.receivedTrack=payload.track_id
    self.decoder=require("cc.audio.dfpwm").make_decoder(); self.receiveQueue={}; self.expectedSequence=0; self.playing=true; self.status="Receiving"
  end
  if type(payload.sequence)~="number" or payload.sequence<=self.expectedSequence then return end
  if payload.sequence~=self.expectedSequence+1 then self.error="Audio packet gap; waiting for next track"; return end
  self.expectedSequence=payload.sequence
  if #self.receiveQueue<12 then table.insert(self.receiveQueue,payload.data) end
end

function M:playReceived()
  if #self.receiveQueue==0 then return end
  local data=self.receiveQueue[1]
  local ok,samples=pcall(self.decoder,data)
  if not ok then self.error=tostring(samples); return end
  local accepted=false
  for _,s in ipairs(peripheral.find("speaker") or {}) do local ok,v=pcall(s.playAudio,s,samples,self.config.music.volume); accepted=accepted or (ok and v) end
  if accepted then table.remove(self.receiveQueue,1) end
  if accepted then self.status="Playing" end
end

function M:applyRemote(state)
  if type(state)~="table" then return end
  local changed=(state.current and self.current and state.current.id~=self.current.id) or (state.current and not self.current) or (not state.current and self.current)
  self.queue=type(state.queue)=="table" and state.queue or self.queue
  self.config.music.volume=tonumber(state.volume) or self.config.music.volume
  if state.loop then self.config.music.loop=state.loop end
  if changed then self:stopLocal(); self.current=state.current end
  if changed then self.playing=false end
  if state.playing and not self.playing then self.playing=true; if self.network.role=="audio" then self.status="Waiting for audio" else self:beginLocal() end
  elseif not state.playing then self.playing=false; self:stopLocal() end
  if self.network.role=="terminal" then self.playing=state.playing==true; self.status=self.playing and "Playing on audio nodes" or "Stopped" end
end

function M:control(action)
  if self.network.role=="terminal" then
    if action=="volume_down" then self.config.music.volume=math.max(0,self.config.music.volume-0.25); action="volume"
    elseif action=="volume_up" then self.config.music.volume=math.min(3,self.config.music.volume+0.25); action="volume"
    elseif action=="loop" then local modes={off="queue",queue="song",song="off"}; self.config.music.loop=modes[self.config.music.loop] or "off"; action="loop" end
    self:publish(action); self.status="Request sent"; return
  end
  if action=="stop" then self.playing=false; self:stopLocal(); self.current=nil; self.status="Stopped"
  elseif action=="pause" then self.playing=false; self:stopLocal(); self.status="Paused"
  elseif action=="resume" then
    if not self.current then self.current=table.remove(self.queue,1) end
    self.playing=self.current~=nil; if self.playing then self:beginLocal() end; self.status=self.playing and "Playing" or "Stopped"
  elseif action=="skip" then
    self.current=table.remove(self.queue,1)
    if not self.current and self.config.music.loop=="song" then self.current=self.lastTrack end
    self:stopLocal(); self.lastTrack=self.current; self.playing=self.current~=nil; if self.playing then self:beginLocal() end; self.status=self.playing and "Playing" or "Stopped"
  elseif action=="volume_down" then self.config.music.volume=math.max(0,self.config.music.volume-0.25); action="volume"
  elseif action=="volume_up" then self.config.music.volume=math.min(3,self.config.music.volume+0.25); action="volume"
  elseif action=="loop" then local modes={off="queue",queue="song",song="off"}; self.config.music.loop=modes[self.config.music.loop] or "off"; action="loop" end
  self:publish(action, nil)
end

return M
