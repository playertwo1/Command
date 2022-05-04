$(document).ready(async function() {
    let container = $("#container");
    let knobs = await $.get("http://192.168.68.102:5000/api/mixer/out", function(data) {
        return data;
    });
    let i = 0;
    for(let knob of knobs) {
        container.append(await newComponent({
            name: 'slider',
            id: `slider-${i}`,
            label: knob.title
        }));
        i++;
    }
});