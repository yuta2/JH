-- @Author: Webster
-- @Date:   2015-01-21 15:21:19
-- @Last Modified by:   Webster
-- @Last Modified time: 2015-04-13 15:53:29
local _L = JH.LoadLangPack

WebSyncData = {
	tData = {},
	bLogin = false,
	uid = 0,
	pw = 0,
}

JH.RegisterCustomData("WebSyncData")
local ROOT_URL = "http://game.j3ui.com/"
local _, _, CLIENT_LANG = GetVersion()
local W = {
	szIniFile = JH.GetAddonInfo().szRootPath .. "RaidGrid_EventScrutiny/ui/WebSyncData.ini",
	szFileList =    ROOT_URL .. "data/top/",
	szFileList2 =   ROOT_URL .. "data/other/",
	szSearch =      ROOT_URL .. "data/search/",
	szUser =        ROOT_URL .. "data/user/",
	szDownload =    ROOT_URL .. "down/json/",
	szLoginUrl =    ROOT_URL .. "user/login/",
}
-- 打开界面
function W.OpenPanel()
	local wnd = Station.Lookup("Normal/WebSyncData") or Wnd.OpenWindow(W.szIniFile, "WebSyncData")
	wnd:BringToTop()
	Station.SetActiveFrame(wnd)
	W.RequestList()
end

function W.ClosePanel()
	Wnd.CloseWindow(Station.Lookup("Normal/WebSyncData"))
	PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
	W.Container = nil
end

function WebSyncData.OnFrameCreate()
	local ui = GUI(this)
	ui:Append("WndButton3", { x = 30, y = 630, txt = _L["sync team"] })
	:Click(W.SyncTeam)
	ui:Append("WndButton3", { x = 180, y = 630, txt = _L["standard data"] })
	:Click(function()
		W.RequestList(W.szFileList)
	end)
	ui:Append("WndButton3", { x = 330, y = 630, txt = _L["Other data"] })
	:Click(function()
		W.RequestList(W.szFileList2)
	end)
	ui:Append("WndButton3", { x = 480, y = 630, txt = g_tStrings.SEARCH }):Click(W.Search)

	ui:Append("WndButton3", { x = 665, y = 630, txt = _L["My Data"] }):Enable(WebSyncData.bLogin):Click(W.MyData)
	ui:Append("WndButton3", { x = 815, y = 630, txt = WebSyncData.bLogin and _L["Logout"] or _L["Login Web Account"] }):Click(function()
		if not WebSyncData.bLogin then
			W.Login()
		else
			W.Logout()
		end
	end)
	ui:Point():RegisterClose(W.ClosePanel)
	W.Container = this:Lookup("PageSet_Menu/Page_FileDownload/WndScroll_FileDownload/WndContainer_FileDownload_List")
end

function W.Login()
	local uid =  WebSyncData.uid
	local pw =  WebSyncData.pw
	if uid == 0 or not pw then
		GetUserInput(_L["Enter User ID"], function(szNum)
			if not tonumber(szNum) then
				JH.Alert(_L["Please enter numbers"])
			else
				uid = tonumber(szNum)
				JH.DelayCall(50, function()
					GetUserInput(_L["Enter password"], function(szText)
						W.CallLogin(uid, szText)
					end)
				end)
			end
		end)
	end
end

function W.Logout()
	WebSyncData.uid = nil
	WebSyncData.pw = nil
	WebSyncData.bLogin = false
	W.ClosePanel()
	W.OpenPanel()
end

function W.CallLogin(uid, pw, fnAction)
	-- web传参不安全 但是只能这样
	if string.len(pw) ~= 32 then
		pw = JH.MD5(pw)
	end
	JH.RemoteRequest(W.szLoginUrl .. "?_" .. GetCurrentTime() .. "&lang=" .. CLIENT_LANG .. "&username=" .. uid .. "&password=" .. pw, function(szTitle, szDoc)
		local result, err = JH.JsonDecode(JH.UrlDecode(szDoc))
		if err then
			JH.Sysmsg2(_L["request failed"])
		else
			if tonumber(result['uid']) > 0 then
				local _, _, url = string.find(result['info'], "src=\"(.-)\"")
				JH.RemoteRequest(url) -- synclogin set cookie
				WebSyncData.uid = uid
				WebSyncData.pw = pw
				WebSyncData.bLogin = true
				W.ClosePanel()
				W.OpenPanel()
				if fnAction then pcall(fnAction) end
			else
				W.Logout()
				JH.Alert(result["info"])
			end
		end
	end)
end

function W.MyData()
	JH.RemoteRequest(W.szLoginUrl .. "?_" .. GetCurrentTime() .. "&lang=" .. CLIENT_LANG, function(szTitle, szDoc)
		local result, err = JH.JsonDecode(JH.UrlDecode(szDoc))
		if err then
			JH.Sysmsg2(_L["request failed"])
		else
			if tonumber(result['uid']) > 0 then
				W.CallMyData()
			else
				WebSyncData.bLogin = false
				W.ClosePanel()
				W.OpenPanel()
				W.CallLogin(WebSyncData.uid, WebSyncData.pw, W.CallMyData)
			end
		end
	end)
end
function W.CallMyData()
	W.RequestList(W.szUser)
end
function W.Search()
	GetUserInput(_L["Enter thread ID"], function(szNum)
		if not tonumber(szNum) then
			JH.Alert(_L["Please enter numbers"])
		else
			W.RequestList(W.szSearch ..szNum)
		end
	end)
end

-- 列表请求
function W.RequestList(szUrl)
	szUrl = szUrl or W.szFileList
	W.Container:Clear()
	W.AppendItem({ title = "", author = "Laoding..." }, 1)
	local szCacheTime = FormatTime("%Y.%m.%d.%H.%M", GetCurrentTime()) -- 得益于IE缓存 1分钟一次
	JH.RemoteRequest(szUrl .. "?_" .. szCacheTime .. "&lang=" .. CLIENT_LANG,function(szTitle, szDoc)
		local result, err = JH.JsonDecode(JH.UrlDecode(szDoc))
		if err then
			JH.Sysmsg2(_L["request failed"])
		else
			W.ListCallBack(result)
		end
	end)
end

function W.ListCallBack(result)
	if not Station.Lookup("Normal/WebSyncData") then return end
	W.Container:Clear()
	W.UseData = nil
	if result["msg"] then
		return JH.Alert(result["msg"])
	end
	for k, v in ipairs(result["data"]) do
		W.AppendItem(v, k)
	end
	W.Container:FormatAllContentPos()
end

function W.TimeToDate(nTime)
	local nNow = GetCurrentTime()
	local nTime = tonumber(nTime) or nNow
	local ndifference = nNow - nTime
	local fn = function(n)
		return string.format("%02d", n)
	end
	if ndifference < 60 then
		return _L["now"]
	elseif ndifference < 3600 then
		return _L("%d mins ago", ndifference / 60)
	elseif ndifference < 86400 then
		return _L("%d hours ago", ndifference / 3600)
	else
		return _L("%d days ago", ndifference / 86400)
	end
end

function W.MenuTip(hItem, text)
	local x, y = hItem:GetAbsPos()
	local w, h = hItem:GetSize()
	local szXml = GetFormatText(text, 47, 255, 255, 255)
	OutputTip(szXml, 435, {x, y, w, h})
end

function W.AppendItem(data, k)
	local wnd = W.Container:AppendContentFromIni(JH.GetAddonInfo().szRootPath .. "RaidGrid_EventScrutiny/ui/Data_ListItem.ini", "WndWindow")
	local item = wnd:Lookup("", "")
	if k % 2 == 0 then
		item:Lookup("Image_Line"):Hide()
	end
	if item then
		item.data = data
		item:Lookup("Text_Author"):SetText(data.author)
		item:Lookup("Text_Title"):SetText(data.title)
		if data.tid then
			local nTime = GetCurrentTime()
			local szDate = W.TimeToDate(data.dateline)
			item:Lookup("Text_Download"):SetText(szDate)
			if (nTime - data.dateline) < 86400 then
				item:Lookup("Text_Download"):SetFontColor(255, 255, 0)
			end
			item.OnItemMouseEnter = function()
				item:Lookup("Image_CoverBg"):Show()
				W.MenuTip(item:Lookup("Text_Author"), data.title)
			end
			item.OnItemMouseLeave = function()
				item:Lookup("Image_CoverBg"):Hide()
				HideTip()
			end
			item.OnItemLButtonClick = function()
				if W.UseData then
					W.UseData:Lookup("Image_Unused"):Hide()
				end
				W.UseData = this
				this:Lookup("Image_Unused"):Show()
			end

			if data.color then
				item:Lookup("Text_Title"):SetFontColor(tonumber(string.sub(data.color, 0, 2), 16), tonumber(string.sub(data.color, 2, 4), 16), tonumber(string.sub(data.color, 4, 6), 16))
			end
			local btn = wnd:Lookup("WndButton")
			local btn2 = wnd:Lookup("WndButton2")
			btn.OnLButtonClick = function()
				W.DoanloadData(data)
			end
			btn2.OnLButtonClick = function()
				local url = ROOT_URL .. "#file/".. data.tid
				if data.url then
					url = "http://" .. data.url
				end
				OpenInternetExplorer(url)
			end
			if data.url then
				btn2:Lookup("","Text_Default2"):SetText(_L["details"])
				btn:Hide()
			end
			if WebSyncData.tData.tid and WebSyncData.tData.tid == data.tid then
				item:Lookup("Text_Title"):SetFontColor(255, 255, 0)
				if WebSyncData.tData.md5 == data.md5 then
					btn:Lookup("","Text_Default"):SetText(_L["select"])
				else
					btn:Lookup("","Text_Default"):SetText(_L["update"])
					btn:Lookup("","Text_Default"):SetFontColor(255, 255, 0)
				end
			end
		else
			wnd:Lookup("WndButton"):Hide()
			wnd:Lookup("WndButton2"):Hide()
		end
	end
end

function W.DoanloadData(data)
	local me = GetClientPlayer()
	if data.tid then
	local wnd = GUI.CreateFrame("RGES_Data",{ w = 740,h = 300,title = _L["JH"] ,drag = true,close = true }):RegisterClose()
		data.color = data.color or "ffffff"
		wnd:Append("Text", { w = 685, h = 60, x = 0, y = 0, txt = data.title, font = 40, multi = true, align = 1, color = { tonumber(string.sub(data.color, 0, 2), 16), tonumber(string.sub(data.color, 2, 4), 16), tonumber(string.sub(data.color, 4, 6), 16) } })
		wnd:Append("Text", { w = 685, h = 30, x = 0, y = 65, txt = "By:" .. data.author, font = 40, align = 1 })
		wnd:Append("WndButton3", { x = 145, y = 120, txt = _L["Cover data"] }):Click(function()
			wnd:Remove()
			W.CallDoanloadData(data, true)
		end)
		wnd:Append("WndButton3", { x = 400, y = 120, txt = _L["Merge data"] }):Click(function()
			wnd:Remove()
			W.CallDoanloadData(data)
		end)
	end
end

function W.CallDoanloadData(data, bOverride)
	JH.Alert(g_tStrings.STR_WAIT_UPDATE)
	-- 简单本地缓存一下
	local szPath = JH.GetAddonInfo().szRootPath .. "RaidGrid_EventScrutiny/alldat/"
	local szFileName = "remote_data_".. data.tid .."_" .. CLIENT_LANG .. "_" .. data.md5 .. ".jx3dat"

	local function fnAction(szFile)
		pcall(RaidGrid_Base.LoadSettingsFileNew, szFile, bOverride)
		JH.Alert(g_tStrings.STR_UPDATE_SUCCESS .. "\n\n" .. data.title)
		WebSyncData.tData = data
		local me = GetClientPlayer()
		if me.IsInParty() then JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "WebSyncTean", "Load", data.title) end
	end

	if IsFileExist(szPath .. szFileName) then -- 本地文件存在则优先
		fnAction(szFileName)
	else -- 否则 remote request
		JH.RemoteRequest(W.szDownload .. data.tid .. "?_" .. GetCurrentTime() .. "&lang=" .. CLIENT_LANG, function(szTitle, szDoc)
			local tab, err = JH.JsonToTable(szDoc)
			if err then
				return JH.Alert(_L["update failed! Please try again."])
			end
			SaveLUAData(szPath .. szFileName, tab) -- 缓存文件
			fnAction(szFileName)
		end)
	end
end

function W.SyncTeam()
	if not W.UseData then
		return JH.Alert(g_tStrings.MSG_CHOOSE_FILE_EMPTY)
	end
	local me = GetClientPlayer()
	if not me.IsInParty() then
		return JH.Alert(_L["You are not in the team."])
	end
	if not JH.IsLeader() and not JH_About.CheckNameEx() then
		return JH.Alert(_L["You are not team leader."])
	end
	JH.Confirm(_L["Confirm?"], function()
		local t = W.UseData.data
		JH.BgTalk(PLAYER_TALK_CHANNEL.RAID, "WebSyncTean", "WebSyncTean", JH.AscIIEncode(JH.JsonEncode(t)))
	end)
end

JH.RegisterEvent("ON_BG_CHANNEL_MSG",function()
	local data = JH.BgHear("WebSyncTean", true)
	if data then
		if data[1] == "WebSyncTean" then
			local dat = JH.JsonDecode(JH.AscIIDecode(data[2]))
			W.DoanloadData(dat)
		end
		if data[1] == "Load" then
			JH.Sysmsg(_L("%s use %s data", arg3, data[2]))
		end
	end
end)

local UIProtect = {
	OpenPanel = W.OpenPanel,
}
setmetatable(WebSyncData, { __index = UIProtect, __metatable = true, __newindex = function() --[[ print("Protect") ]] end } )
