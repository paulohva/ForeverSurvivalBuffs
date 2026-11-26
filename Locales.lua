--------------------------------------------------------------------------------
-- Translations. The addon follows the game client's language:
-- ns.L["English text"] is translated below, English otherwise. Spell and class
-- names always come from the game, already translated.
-- To add a language, copy the ptBR block and change the locale code.
--------------------------------------------------------------------------------

local _, ns = ...

local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

local locale = GetLocale and GetLocale() or "enUS"

if locale == "ptBR" then
	-- buffs
	L["Well Fed"] = "Bem Alimentado"
	L["Camp buff"] = "Buff de acampamento"
	L["Sleeping bag (Well Rested)"] = "Saco de dormir (Bem Descansado)"
	L["Sharpening stone or weightstone"] = "Pedra de afiar ou de peso"
	L["Poison"] = "Veneno"
	L["Weapon imbue or stone"] = "Imbuição de arma ou pedra"
	L["Wizard oil or mana oil"] = "Óleo de feiticeiro ou de mana"
	L["main hand"] = "mão principal"
	L["off hand"] = "mão secundária"
	L["Eat food that makes you Well Fed."] = "Coma algo que deixe você Bem Alimentado."
	L["Rest at a campfire until you get the one-hour camp buff."] =
		"Descanse perto de uma fogueira até receber o buff de acampamento de uma hora."
	L["Use your Cozy Sleeping Bag for extra experience."] = "Use o seu Saco de Dormir Aconchegante para ganhar mais experiência."
	L["Put a temporary enhancement on this weapon."] = "Aplique uma melhoria temporária nesta arma."
	L["Cast it on yourself."] = "Lance em você mesmo."

	-- reminders
	L["Missing: %s"] = "Falta: %s"
	L["Alt + drag to move."] = "Alt + arrastar para mover."
	L["Drag to move. Lock it in the options when done."] = "Arraste para mover. Depois trave nas opções."
	L["Right-click: choose your buffs"] = "Clique direito: escolher os seus buffs"
	L["ForeverSurvivalBuffs: drag to move"] = "ForeverSurvivalBuffs: arraste para mover"

	-- buffs window
	L["Tick the buffs you want to be reminded of."] = "Marque os buffs que quer que sejam lembrados."
	L["Survival"] = "Sobrevivência"
	L["%s buffs"] = "Buffs de %s"
	L["Class buffs"] = "Buffs de classe"
	L["Active"] = "Ativo"
	L["Missing"] = "Faltando"
	L["Not learned"] = "Não aprendido"
	L["No weapon"] = "Sem arma"
	L["No sleeping bag"] = "Sem saco de dormir"
	L["Max level"] = "Nível máximo"
	L["Not available"] = "Indisponível"
	L["Ending soon"] = "Acabando"
	L["%s ends in %s"] = "%s acaba em %s"
	L["Buffs can't be read right now (combat or instance); this is what was last seen."] =
		"Os buffs não podem ser lidos agora (combate ou instância); isto é o que foi visto por último."
	L["Outside"] = "Fora"
	L["Dungeons and raids"] = "Masmorras e raides"
	L[" (now)"] = " (agora)"
	L["The buffs to be reminded of inside dungeons and raids. Until you change it, it's the same as the other list."] =
		"Os buffs a lembrar dentro de masmorras e raides. Enquanto não a mudar, é igual à outra lista."
	L["The buffs to be reminded of everywhere else."] = "Os buffs a lembrar em todos os outros lugares."

	-- minimap button and menu
	L["Left-click: choose your buffs"] = "Clique esquerdo: escolher os seus buffs"
	L["Right-click: options"] = "Clique direito: opções"
	L["Choose your buffs..."] = "Escolher os seus buffs..."
	L["Show reminders"] = "Mostrar lembretes"
	L["Hide in combat"] = "Esconder em combate"
	L["Unlock to move"] = "Destravar para mover"
	L["Settings..."] = "Configurações..."
	L["Hide minimap button"] = "Esconder o botão do minimapa"
	L["Minimap button hidden. /fsb minimap brings it back."] = "Botão do minimapa escondido. /fsb minimap traz de volta."

	-- settings
	L["Reminders on."] = "Lembretes ligados."
	L["Reminders off."] = "Lembretes desligados."
	L["Buffs"] = "Buffs"
	L["Buffs to remind"] = "Buffs a lembrar"
	L["Choose..."] = "Escolher..."
	L["Tick the survival buffs, class buffs and weapon enhancements you want to be reminded of."] =
		"Marque os buffs de sobrevivência, de classe e as melhorias de arma que quer que sejam lembrados."
	L["Reminders"] = "Lembretes"
	L["Show an icon for each chosen buff you're missing."] = "Mostra um ícone para cada buff escolhido que estiver faltando."
	L["Hide the reminders during a fight. In combat the game doesn't let addons see your buffs anyway."] =
		"Esconde os lembretes durante a luta. Em combate o jogo não deixa os addons verem os seus buffs."
	L["Lock position"] = "Travar posição"
	L["Untick to show every chosen buff and drag the row where you want it. Alt + drag always works."] =
		"Desmarque para mostrar todos os buffs escolhidos e arrastar a fila para onde quiser. Alt + arrastar funciona sempre."
	L["Icon size"] = "Tamanho dos ícones"
	L["The size of the reminder icons."] = "O tamanho dos ícones de lembrete."
	L["Position"] = "Posição"
	L["Reset"] = "Restaurar"
	L["Put the reminders back in their first place, below the middle of the screen."] =
		"Volta a pôr os lembretes no lugar inicial, abaixo do centro da tela."
	L["Minimap"] = "Minimapa"
	L["Show minimap button"] = "Mostrar botão no minimapa"
	L["Left-click opens the buffs window, right-click the options."] =
		"O clique abre a janela dos buffs, o botão direito as opções."
	L["The options can't be opened in combat. Try again after the fight."] =
		"As opções não podem ser abertas em combate. Tente de novo depois da luta."

	-- slash commands
	L["Commands:"] = "Comandos:"
	L["open the window to choose your buffs"] = "abre a janela para escolher os seus buffs"
	L["turn the reminders on or off"] = "liga ou desliga os lembretes"
	L["move the reminders, then lock them in place"] = "move os lembretes e depois trava no lugar"
	L["put the reminders back in their first place"] = "volta a pôr os lembretes no lugar inicial"
	L["open the settings"] = "abre as configurações"
	L["show or hide the minimap button"] = "mostra ou esconde o botão do minimapa"
	L["list your buffs and what the addon sees"] = "lista os seus buffs e o que o addon vê"
	L["Alt + drag the reminders to move them."] = "Alt + arrastar os lembretes para movê-los."
	L["Drag the reminders where you want them, then type /fsb lock."] =
		"Arraste os lembretes para onde quiser e depois digite /fsb lock."
	L["Reminders locked. Alt + drag still moves them."] = "Lembretes travados. Alt + arrastar ainda os move."
	L["Reminders back in their first place."] = "Lembretes de volta ao lugar inicial."
	L["This client has no options panel for addons."] = "Este cliente não tem painel de opções para addons."
	L["Debug messages on."] = "Mensagens de depuração ligadas."
	L["Debug messages off."] = "Mensagens de depuração desligadas."
end
