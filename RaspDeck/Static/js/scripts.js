function onChangeVolSlider(value) {
    console.log(`val: ${value}`);
}

$(document).ready(async function() {
    let container = $("#container");
    /*let knobs = await $.get("http://192.168.68.102:5000/api/mixer/out", function(data) {
        return data;
    });*/
    let i = 0;
    for(i=0;i<10;i++) {
        let data = {
            attributes: {
                name: 'slider',
                id: `slider-${i}`,
                label: `knob-${i}`,
                orient: 'vertical'
            },
            callback: onChangeVolSlider
        }
        await newComponent(container, data);
    }
});