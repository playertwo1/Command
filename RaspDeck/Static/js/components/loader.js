(function() {
    if (!window.jQuery) {  
        var startingTime = new Date().getTime();
        var script = document.createElement("script");
        script.src = 'https://ajax.googleapis.com/ajax/libs/jquery/3.6.0/jquery.min.js';
        script.type = 'text/javascript';
        script.onload = function() {
            var $ = window.jQuery;
        $(function() {
                var endingTime = new Date().getTime();
                var tookTime = endingTime - startingTime;
                console.log("jQuery loaded, after " + tookTime + " milliseconds!");
            });
        };
        document.getElementsByTagName("head")[0].appendChild(script);
    }
    loadResource('common','css');
})();

function isResourceLoaded(resource) {
    let scripts = document.getElementsByTagName('script');
    let links = document.getElementsByTagName('link');
    let elements = undefined;
    if(resource.type == 'text/css') elements = links;
    else if(resource.type == 'text/javascript') elements = scripts;
    let result = false;
    if(elements != undefined) {
        for(el of elements) {
            if(resource.type == 'text/css') {
                result = el.href == resource.href;
            } else if(resource.type == 'text/javascript') {
                result = el.src == resource.src;
            }
            if(result) break;
        }
    }
    return result;
  }

function loadResource(filename, type) {
    let resource = undefined;
    const dir = (('common' == filename) ? `js/components/${filename}` : `js/components/${filename}/${filename}`);
    if(type == 'css') {
        let head = document.getElementsByTagName('head')[0];
        resource = document.createElement('link');
        resource.rel = 'stylesheet';
        resource.type = 'text/css';
        resource.href = dir + '.css';
        if(isResourceLoaded(resource)) {
            resource = undefined;
        }
        if(resource != undefined) head.appendChild(resource);
    } else if(type == 'js') {
        body = document.getElementsByTagName('body')[0];
        resource = document.createElement("script");
        resource.src = dir + '.js';
        resource.type = 'text/javascript';
        if(isResourceLoaded(resource)) {
            resource = undefined;
        }
        if(resource != undefined) body.appendChild(resource);
    }
}

async function newComponent(container, data) {
    let result = `<g5-slider></g5-slider>`;
    let attributes = data.attributes;
    if(attributes.id != undefined) {
        result = $.parseHTML(result);
        for(obj of Object.keys(attributes)) {
            $(result).attr(obj, attributes[obj])
            container.append(result)
            $(result)[0].setCallback(data.callback)
        }
    }
    return result;
}