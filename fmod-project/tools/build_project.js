var m = studio.project.model;
var ws = studio.project.workspace;
var mixer = ws.mixer;
var P = studio.system.print;

var projectDir = studio.project.filePath.replace(/[\\\/][^\\\/]+$/, "");
var SRC = projectDir + "/../source_audio/";
var BANK_OUT = "../../parallel-gaming/banks";

function each(list, fn) { for (var i = 0; i < list.length; i++) fn(list[i]); }
function del(list) { each(list, function (o) { try { studio.project.deleteObject(o); } catch (e) { P("skip delete " + o.entity + ": " + e); } }); }
function tryDo(label, fn) { try { return fn(); } catch (e) { P("WARN " + label + ": " + e); return null; } }

del(m.Event.findInstances());
del(m.Snapshot.findInstances());
del(m.MixerVCA.findInstances());
del(m.MixerGroup.findInstances());
del(m.ParameterPreset.findInstances());
del(m.AudioFile.findInstances());
del(m.EventFolder.findInstances().filter(function (f) { return f !== ws.masterEventFolder; }));
del(m.Bank.findInstances().filter(function (b) { return !b.isMasterBank; }));
del(m.Platform.findInstances().filter(function (pl) { return pl.name !== "Desktop"; }));

var master = m.Bank.findInstances().filter(function (b) { return b.isMasterBank; })[0];
master.name = "Master";

var files = {};
function imp(name) {
    if (files[name]) return files[name];
    var a = studio.project.importAudioFile(SRC + name + ".ogg");
    if (!a) throw "import failed " + name;
    files[name] = a;
    return a;
}

function folder(name) {
    var f = studio.project.create("EventFolder");
    f.name = name;
    f.folder = ws.masterEventFolder;
    return f;
}

function group(name, out, volume) {
    var g = studio.project.create("MixerGroup");
    g.name = name;
    g.output = out || mixer.masterBus;
    if (volume !== undefined) g.volume = volume;
    return g;
}

function vca(name, strips) {
    var v = studio.project.create("MixerVCA");
    v.name = name;
    v.mixer = mixer;
    each(strips, function (s) { s.relationships.masters.add(v); });
    return v;
}

function preset(name, min, max) {
    return ws.addGameParameter({ name: name, type: studio.project.parameterType.User, min: min, max: max });
}

function paramOf(pp) { return pp.parameter ? pp.parameter : pp; }

function curve(obj, prop, pp, points) {
    var c = obj.addAutomator(prop).addAutomationCurve(paramOf(pp));
    each(points, function (pt) { c.addAutomationPoint(pt[0], pt[1]); });
    return c;
}

function newEvent(fold, name, bus) {
    var ev = studio.project.create("Event");
    ev.name = name;
    ev.folder = fold;
    ev.mixerInput.output = bus;
    ev.relationships.banks.add(master);
    return ev;
}

function single(tr, ev, name, start, volume) {
    var f = imp(name);
    var snd = tr.addSound(ev.timeline, "SingleSound", start || 0, f.length);
    snd.audioFile = f;
    if (volume !== undefined) snd.volume = volume;
    return snd;
}

function multi(tr, ev, names, volume) {
    var len = 0;
    each(names, function (n) { len = Math.max(len, imp(n).length); });
    var ms = tr.addSound(ev.timeline, "MultiSound", 0, len);
    each(names, function (n) {
        var s = studio.project.create("SingleSound");
        s.audioFile = imp(n);
        s.owner = ms;
    });
    if (volume !== undefined) ms.volume = volume;
    return ms;
}

function oneShot(fold, name, bus, layers, opts) {
    opts = opts || {};
    var ev = newEvent(fold, name, bus);
    var first = null;
    each(layers, function (layer, i) {
        var tr = ev.addGroupTrack("Layer " + (i + 1));
        var snd = layer.length > 1 ? multi(tr, ev, layer.names || layer, opts.volume) : single(tr, ev, layer[0], 0, opts.volume);
        if (layer.delay) snd.start = layer.delay;
        if (opts.randomPitch) tryDo("random pitch " + name, function () { snd.addModulator("RandomizerModulator", "pitch").amount = opts.randomPitch; });
        if (opts.randomVolume) tryDo("random volume " + name, function () { snd.addModulator("RandomizerModulator", "volume").amount = opts.randomVolume; });
        if (!first) first = snd;
    });
    if (opts.pan) tryDo("pan " + name, function () {
        ev.addGameParameter(opts.pan);
        curve(ev.masterTrack.mixerGroup.panner, "stereoPan", opts.pan, [[-1, -70], [1, 70]]);
    });
    if (opts.pitchParam) tryDo("pitch param " + name, function () {
        ev.addGameParameter(opts.pitchParam[0]);
        curve(ev.masterTrack.mixerGroup, "pitch", opts.pitchParam[0], opts.pitchParam[1]);
    });
    if (opts.masterVolume !== undefined) ev.masterTrack.mixerGroup.volume = opts.masterVolume;
    return ev;
}

function fades(ev, attackMs, releaseMs) {
    tryDo("adsr " + ev.name, function () {
        var md = ev.masterTrack.mixerGroup.addModulator("ADSRModulator", "volume");
        md.attackTime = attackMs;
        md.releaseTime = releaseMs;
        md.initialValue = -80;
        md.finalValue = -80;
    });
}

function loopEvent(ev, length) {
    tryDo("loop region " + ev.name, function () { ev.addMarkerTrack().addRegion(0, length, "Loop", studio.project.regionLoopMode.Looping); });
}

var musicBus = group("Music", null, -4);
var sfxBus = group("SFX", null, -2);
var uiBus = group("UI", null, -3);
vca("Music", [musicBus]);
vca("SFX", [sfxBus, uiBus]);
var musicLowpass = musicBus.effectChain.addEffect("LowpassSimpleEffect");
musicLowpass.cutoff = 22000;

var pRedness = preset("Redness", 0, 1);
var pIntensity = preset("Intensity", 0, 1);
var pMode = preset("Mode", 0, 1);
var pCombo = preset("Combo", 0, 8);
var pPan = preset("Pan", -1, 1);

var fMusic = folder("Music");
var fSfx = folder("SFX");
var fUi = folder("UI");

var desktop = newEvent(fMusic, "Desktop", musicBus);
var bossa = single(desktop.addGroupTrack("Bossa"), desktop, "music_desktop_bossa", 0, 6);
loopEvent(desktop, bossa.length);
fades(desktop, 1200, 1500);

var theme = newEvent(fMusic, "Theme", musicBus);
theme.addGameParameter(pRedness);
theme.addGameParameter(pIntensity);
theme.addGameParameter(pMode);
var gameTrack = theme.addGroupTrack("Game");
var zenTrack = theme.addGroupTrack("Zen");
var gameSnd = single(gameTrack, theme, "music_game_brassy_bubbles", 0, -3);
var zenSnd = single(zenTrack, theme, "music_zen_underwater", 0, 1);
gameSnd.isAsync = true;
gameSnd.looping = true;
zenSnd.isAsync = true;
zenSnd.looping = true;
curve(gameTrack.mixerGroup, "volume", pMode, [[0, 0], [0.4, -80]]);
curve(zenTrack.mixerGroup, "volume", pMode, [[0.6, -80], [1, 0]]);
var themeLp = theme.masterTrack.mixerGroup.effectChain.addEffect("LowpassSimpleEffect");
curve(themeLp, "cutoff", pRedness, [[0, 900], [0.15, 2500], [0.35, 9000], [0.55, 22000], [1, 22000]]);
curve(theme.masterTrack.mixerGroup, "pitch", pIntensity, [[0, 0], [0.8, 0], [1, 1]]);
curve(theme.masterTrack.mixerGroup, "volume", pIntensity, [[0, -2], [0.6, 0], [1, 2]]);
fades(theme, 900, 1400);

oneShot(fUi, "Startup", uiBus, [["ui_startup"]], { volume: 8 });
oneShot(fUi, "Click", uiBus, [["kenney_select_002", "kenney_pluck_001"]], { randomPitch: 2 });
oneShot(fUi, "Hover", uiBus, [["kenney_tick_001"]], { volume: -8, randomPitch: 3 });
oneShot(fUi, "WindowOpen", uiBus, [["kenney_maximize_006"]], { volume: -2 });
oneShot(fUi, "WindowClose", uiBus, [["kenney_minimize_006"]], { volume: -2 });
oneShot(fUi, "Notify", uiBus, [["kenney_question_001"]], {});
oneShot(fUi, "Error", uiBus, [["kenney_error_006"]], {});

oneShot(fSfx, "Brush", sfxBus, [["kenney_drop_002", "kenney_drop_003", "kenney_drop_004"]], { randomPitch: 4, randomVolume: 3, pan: pPan, volume: -5 });
oneShot(fSfx, "TileMatch", sfxBus, [["kenney_glass_001"]], { pan: pPan, pitchParam: [pCombo, [[0, 0], [8, 12]]] });
oneShot(fSfx, "TileLost", sfxBus, [["kenney_error_004"]], { pan: pPan, volume: -4 });
oneShot(fSfx, "BlobSpawn", sfxBus, [["kenney_digital_pepSound1"]], { pan: pPan, randomPitch: 3, volume: -6 });
oneShot(fSfx, "BlobPop", sfxBus, [["pop_cogitollc_1", "pop_cogitollc_3", "pop_cogitollc_5"]], { pan: pPan, randomPitch: 5 });
oneShot(fSfx, "BoardClear", sfxBus, [["kenney_confirmation_002"], ["kenney_digital_zapThreeToneUp"]], { pitchParam: [pCombo, [[0, 0], [8, 5]]], volume: -2 });
oneShot(fSfx, "BoardFail", sfxBus, [["kenney_digital_lowDown"], ["kenney_error_004"]], {});
oneShot(fSfx, "TimeWarning", sfxBus, [["kenney_bong_001"]], { pitchParam: [pCombo, [[0, 0], [8, 8]]] });
oneShot(fSfx, "RoundEnd_Win", sfxBus, [["sfx_win_clear_skies"]], {});
oneShot(fSfx, "RoundEnd_Lose", sfxBus, [["kenney_digital_zapThreeToneDown"]], {});
oneShot(fSfx, "BubbleSpawn", sfxBus, [["pop_cogitollc_2", "pop_cogitollc_4"]], { pan: pPan, volume: -10, randomPitch: 6 });
oneShot(fSfx, "PowerFreeze", sfxBus, [["kenney_glass_004"]], { pan: pPan });
oneShot(fSfx, "PowerBucket", sfxBus, [["kenney_drop_004"], ["kenney_digital_powerUp2"]], { pan: pPan });
oneShot(fSfx, "PowerMega", sfxBus, [["kenney_digital_powerUp7"]], { pan: pPan });
oneShot(fSfx, "PowerRinse", sfxBus, [["kenney_digital_phaserUp3"], ["pop_cogitollc_6"]], { pan: pPan });
oneShot(fSfx, "PowerTime", sfxBus, [["kenney_digital_threeTone1"]], { pan: pPan, volume: -3 });
oneShot(fSfx, "BucketFill", sfxBus, [["kenney_glass_002"], ["kenney_drop_002"]], { pan: pPan });
oneShot(fSfx, "TileShift", sfxBus, [["kenney_switch_003"]], { pan: pPan });
oneShot(fSfx, "Perfect", sfxBus, [["kenney_confirmation_004"]], {});

function snapshot(name, props) {
    var snap = studio.project.create("Snapshot");
    snap.name = name;
    tryDo("snapshot list " + name, function () { mixer.snapshotList.relationships.items.add(snap); });
    tryDo("snapshot bank " + name, function () { snap.relationships.banks.add(master); });
    each(props, function (pr) {
        tryDo("snapshot " + name + " " + pr[1], function () {
            var sp = studio.project.create("SnapshotProperty");
            sp.propertyName = pr[1];
            sp.value = pr[2];
            sp.snapshot = snap;
            sp.automatableObject = pr[0];
        });
    });
    return snap;
}
snapshot("Pause", [[musicBus, "volume", -12], [sfxBus, "volume", -8], [musicLowpass, "cutoff", 700]]);
snapshot("Freeze", [[musicBus, "pitch", -3], [musicLowpass, "cutoff", 2600]]);

ws.builtBanksOutputDirectory = BANK_OUT;
studio.project.save();

P("events: " + m.Event.findInstances().map(function (e) { return e.getPath(); }).sort().join(", "));
P("snapshots: " + m.Snapshot.findInstances().map(function (e) { return e.getPath(); }).join(", "));
var ok = studio.project.build({ platforms: "Desktop" });
P("build " + (ok ? "OK" : "FAILED") + " -> " + BANK_OUT);
