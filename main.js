const { app, BrowserWindow } = require('electron');

let win;

function createWindow() {
    win = new BrowserWindow({
       width: 800,
       height:480,
       backgroundColor: '#000',
       icon: `file://${__dirname}/dist/assets/logo.png`,
       frame: false
    })
    
    win.loadURL(`file://${__dirname}/dist/inde.html`)

    win.webContents.openDevTools()

    win.on('closed', function () {
        win = null
    })
}

app.on('ready', createWindow)

app.on('window-all-closed', function () {
    if(process.platform !== 'darwin') {
        app.quit()
    }
})

app.on('activate', function () {
    if(win === null) {
        createWindow()
    }
})