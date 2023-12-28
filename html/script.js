// html/script.js

document.addEventListener('DOMContentLoaded', (event) => {
    const radioList = document.getElementById('radioList');
    const stopRadioButton = document.getElementById('stopRadio');
    const volumeSlider = document.getElementById('volumeSlider');
    const volumeValue = document.getElementById('volumeValue');
    const currentradio = document.getElementById('currentRadio');
    const radioframe = document.getElementById('radioIcon');
    radioframe.style.visibility = 'hidden';
   
    let currentVolume = 50;

    window.addEventListener('message', (event) => {
        const data = event.data;

        if (data.openRadioMenu) {
            radioList.innerHTML = '';

            data.radios.forEach(radio => {
                const listItem = document.createElement('li');
                listItem.innerText = radio.name;
                listItem.addEventListener('click', () => {
                    sendRadioSelection(radio.name,radio.url);
                    radioframe.style.visibility = 'visible';
                    currentradio.style.visibility = 'visible';
                    currentradio.innerHTML = ` <p id="currentRadioName style="color="green"">`+radio.name+`</p>`
                    
                });
                radioList.appendChild(listItem);
            });

            if (data.currentlyPlayingRadio) {
                stopRadioButton.style.display = 'block';
                stopRadioButton.addEventListener('click', () => {
                    sendStopRadio();
                });
            } else {
                //stopRadioButton.style.display = 'none';
            }

            document.getElementById('radioMenu').style.display = 'block';
        }
        if (data.close == true) {
            if(data.closeall)
            {
                closeRadioMenu(true);
            }else{
                closeRadioMenu(false);
            }
        }

        if (data.showradio == true) {
            radioframe.style.visibility = 'visible';
            currentradio.style.visibility = 'visible';
            currentradio.innerHTML = ` <p id="currentRadioName style="color="black"">`+data.name+`</p>`
        }
        
    });

    function sendRadioSelection(name ,url) {
        const data = { radioname: name, url, volume: currentVolume };  
        sendData('playRadio', data);
    }

    function sendStopRadio() {
        sendData('stopRadio', {});
    }

    function sendData(eventName, data) {
        fetch(`https://${GetParentResourceName()}/${eventName}`, {
            method: 'post',
            headers: {
                'Content-Type': 'application/json; charset=utf-8',
            },
            body: JSON.stringify(data),
        });
    }

    // Volume control
    volumeSlider.addEventListener('input', () => {
        currentVolume = volumeSlider.value;
        volumeValue.innerText = `${currentVolume}%`;
        sendData('updateVolume', { volume: currentVolume});
    });

    // Close the menu on Escape key press
    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape') {
            closeRadioMenu(false);
        }
    });

    function closeRadioMenu(disableall) {
        data = null;
        fetch(`https://${GetParentResourceName()}/closeradio`, {
            method: 'post',
            headers: {
                'Content-Type': 'application/json; charset=utf-8',
            },
            body: JSON.stringify(data),
        });
        if (!disableall) {
        document.getElementById('radioMenu').style.display = 'none';
        }else{
            document.getElementById('radioMenu').style.display = 'none';
            document.getElementById('currentRadio').style.visibility = 'hidden';
            radioframe.style.visibility = 'hidden';
        }
    }
});

