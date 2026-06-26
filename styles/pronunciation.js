function say(word) {
  const u = new SpeechSynthesisUtterance(word);
  u.lang = "en-US";
  u.rate = 0.85;
  speechSynthesis.speak(u);
}