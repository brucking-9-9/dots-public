import QtQuick

// waybar's clock tooltip: the year calendar (`mode: year`, 3 months per row,
// week numbers on the right) in the config's colours — months #acb0d0,
// weeks #7aa2f7, weekdays #e0af68, days #acb0d0, today #41a6b5 underlined —
// as <tt><small> text. Non-breaking spaces keep the columns in rich text.
Grid {
    id: cal
    columns: 3
    columnSpacing: 18
    rowSpacing: 8
    property date today: new Date()
    readonly property string sp: " "

    function pad(s, n) { while (s.length < n) s += sp; return s; }
    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - y0) / 86400000 + 1) / 7);
    }
    function month(y, m) {
        const lines = [];
        lines.push('<font color="#acb0d0"><b>' + pad(Qt.formatDate(new Date(y, m, 1), "MMMM yyyy"), 25) + '</b></font>');
        lines.push('<font color="#e0af68"><b>' + ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"].join(sp) + '</b></font>');
        const last = new Date(y, m + 1, 0).getDate();
        let d = 1 - new Date(y, m, 1).getDay();
        while (d <= last) {
            let row = "", wk = 0;
            for (let i = 0; i < 7; i++, d++) {
                if (d < 1 || d > last) { row += sp + sp + sp; continue; }
                const s = (d < 10 ? sp : "") + d;
                const isToday = y === today.getFullYear() && m === today.getMonth() && d === today.getDate();
                row += (isToday ? '<font color="#41a6b5"><b><u>' + s + '</u></b></font>' : '<font color="#acb0d0"><b>' + s + '</b></font>') + sp;
                if (!wk) wk = isoWeek(new Date(y, m, d));
            }
            lines.push(row + sp + '<font color="#7aa2f7"><b>W' + wk + '</b></font>');
        }
        return lines.join("<br>");
    }

    Repeater {
        model: 12
        Text {
            required property int index
            textFormat: Text.RichText
            text: cal.month(cal.today.getFullYear(), index)
            font.family: "CaskaydiaCove Nerd Font"   // the monospace cut (<tt>)
            font.pixelSize: 12                       // <small> of 14
            color: "#acb0d0"
        }
    }
}
