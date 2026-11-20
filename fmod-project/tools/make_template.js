var m = studio.project.model;
var ws = studio.project.workspace;
var p = studio.system.print;

function each(list, fn) { for (var i = 0; i < list.length; i++) fn(list[i]); }
function del(list) { each(list, function (o) { try { studio.project.deleteObject(o); } catch (e) { p("skip " + o.entity + " " + e); } }); }

del(m.Event.findInstances());
del(m.Snapshot.findInstances());
del(m.SnapshotGroup.findInstances());
del(m.MixerVCA.findInstances());
del(m.MixerGroup.findInstances());
del(m.MixerReturn.findInstances());
del(m.Bank.findInstances().filter(function (b) { return !b.isMasterBank; }));
del(m.ParameterPreset.findInstances());
del(m.EffectPreset.findInstances());
del(m.Tag.findInstances());
del(m.AudioFile.findInstances());
each(["EventFolder", "ParameterPresetFolder", "TagFolder", "BankFolder", "AudioFolder", "EffectPresetFolder", "SnapshotFolder"], function (n) {
    if (!m[n]) return;
    del(m[n].findInstances().filter(function (f) {
        return f !== ws.masterEventFolder && f !== ws.masterParameterPresetFolder && f !== ws.masterTagFolder &&
            f !== ws.masterBankFolder && f !== ws.masterAssetFolder && f !== ws.masterEffectPresetFolder && f.parent !== null && f.folder !== undefined && f.folder !== null;
    }));
});
each(m.Platform.findInstances(), function (pl) { p("platform " + pl.name); });
each(["Event", "Snapshot", "MixerGroup", "MixerVCA", "Bank", "AudioFile", "ParameterPreset", "Tag", "EventFolder"], function (n) {
    p("left " + n + ": " + m[n].findInstances().length);
});

var here = studio.project.filePath.replace(/[\\/][^\\/]+$/, "");
studio.project.save(here + "/../RedPainter/RedPainter.fspro");
