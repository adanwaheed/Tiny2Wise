const avatarModel = document.getElementById("avatarModel");
const statusText = document.getElementById("statusText");
const speechText = document.getElementById("speechText");

avatarModel.addEventListener("load", function () {
  statusText.style.display = "none";
  console.log("Avatar loaded successfully");
});

avatarModel.addEventListener("error", function (event) {
  statusText.innerText = "Avatar failed to load";
  console.error("Avatar loading error:", event);
});

function showSpeechBubble(text) {
  speechText.innerText = text;
  speechText.style.display = "block";
}

function hideSpeechBubble() {
  speechText.style.display = "none";
}

window.speakAvatar = function (text) {
  if (!text) return;

  showSpeechBubble(text);

  if ("speechSynthesis" in window) {
    window.speechSynthesis.cancel();

    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = "ur-PK";
    utterance.rate = 0.9;
    utterance.pitch = 1.1;

    utterance.onend = function () {
      hideSpeechBubble();
    };

    utterance.onerror = function () {
      setTimeout(hideSpeechBubble, 2500);
    };

    window.speechSynthesis.speak(utterance);
  } else {
    setTimeout(hideSpeechBubble, 3000);
  }
};

window.playHappy = function () {
  avatarModel.style.transform = "scale(1.08)";

  setTimeout(function () {
    avatarModel.style.transform = "scale(1)";
  }, 450);
};

window.playListening = function () {
  showSpeechBubble("میں سن رہا ہوں...");

  avatarModel.style.transform = "rotateY(-12deg)";

  setTimeout(function () {
    avatarModel.style.transform = "rotateY(0deg)";
    hideSpeechBubble();
  }, 1000);
};

window.stopAvatarSpeech = function () {
  if ("speechSynthesis" in window) {
    window.speechSynthesis.cancel();
  }

  hideSpeechBubble();
};