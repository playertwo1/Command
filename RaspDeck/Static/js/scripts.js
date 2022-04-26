$(document).ready(async function() {
    let container = $("#container");
    for(let i=1; i<= 10; i++) {
        container.append(await newComponent('slider'));
    }
})