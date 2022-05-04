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
    let head = document.getElementsByTagName('head')[0];
    let resource = undefined;
    const dir = `js/components/${filename}/${filename}`;
    if(type == 'css') {
        resource = document.createElement('link');
        resource.rel = 'stylesheet';
        resource.type = 'text/css';
        resource.href = dir + '.css';
        if(isResourceLoaded(resource)) {
            resource = undefined;
        }
    } else if(type == 'js') {
        resource = document.createElement("script");
        resource.src = dir + '.js';
        resource.type = 'text/javascript';
        if(isResourceLoaded(resource)) {
            resource = undefined;
        }
    }
    if(resource != undefined) head.appendChild(resource);
}

async function fetchDataAsync(url) {
    const response = await fetch(url);
    return await response.text();
}

async function loadHtml(filename) {
    const url = `js/components/${filename}/${filename}.html`;
    return await fetchDataAsync(url);
}

async function newComponent(data) {
    let result = await loadHtml(data.name);
    if(result != undefined) {
        loadResource(data.name, 'css');
        loadResource(data.name, 'js');
        if(result != undefined && data.id != undefined) {
            result = $.parseHTML(result);
            $(result).attr('id', data.id);
            sliders.push(data);
        }
        return result;
    }
    return undefined;
}