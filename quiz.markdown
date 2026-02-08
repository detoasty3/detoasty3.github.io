---
layout: page
title: Quiz
permalink: /quiz
---

<h1>Quiz Submission + Answer Database</h1>
  <p class="muted">
    Data is stored in <b>localStorage</b> (browser-only). Refresh-safe, but not shared across devices.
  </p>

  <div class="card">
    <h2>Student Quiz</h2>

    <div class="row">
      <input id="studentName" placeholder="Enter your name..." />
      <button onclick="submitQuiz()">Submit Quiz</button>
      <button onclick="resetQuiz()">Reset Quiz</button>
    </div>

    <div id="quizContainer"></div>

    <div id="result" class="muted"></div>
  </div>

  <div class="card">
    <h2>Admin View (Submissions Database)</h2>
    <p class="muted">Shows all saved submissions in localStorage.</p>

    <div class="row">
      <button onclick="renderAdminTable()">Refresh Table</button>
      <button class="danger" onclick="clearDatabase()">Clear Database</button>
      <button onclick="exportJSON()">Export JSON</button>
      <button onclick="importJSON()">Import JSON</button>
      <input type="file" id="importFile" accept="application/json" style="display:none" />
    </div>

    <div id="adminTable"></div>
  </div>

<script>
  /***********************
   * 1) QUIZ DEFINITION
   ***********************/
  const quiz = [
    {
      id: "q1",
      question: "What is 2 + 2?",
      choices: ["3", "4", "5", "22"],
      answerIndex: 1
    },
    {
      id: "q2",
      question: "Which language runs in the browser?",
      choices: ["Python", "C++", "JavaScript", "Java"],
      answerIndex: 2
    },
    {
      id: "q3",
      question: "What does HTML stand for?",
      choices: [
        "Hyper Trainer Marking Language",
        "Hyper Text Markup Language",
        "High Text Machine Language",
        "Hyperlink and Text Markup Language"
      ],
      answerIndex: 1
    }
  ];

  /****************************
   * 2) "DATABASE" (localStorage)
   ****************************/
  const DB_KEY = "quiz_submissions_v1";

  function loadDB() {
    const raw = localStorage.getItem(DB_KEY);
    return raw ? JSON.parse(raw) : [];
  }

  function saveDB(submissions) {
    localStorage.setItem(DB_KEY, JSON.stringify(submissions));
  }

  function addSubmission(submission) {
    const db = loadDB();
    db.push(submission);
    saveDB(db);
  }

  function clearDatabase() {
    if (!confirm("Clear ALL submissions? This cannot be undone.")) return;
    localStorage.removeItem(DB_KEY);
    renderAdminTable();
    alert("Database cleared.");
  }

  /***********************
   * 3) QUIZ RENDERING
   ***********************/
  function renderQuiz() {
    const container = document.getElementById("quizContainer");
    container.innerHTML = "";

    quiz.forEach((q, idx) => {
      const div = document.createElement("div");
      div.className = "q";

      div.innerHTML = `
        <div><b>Q${idx + 1}.</b> ${q.question}</div>
        ${q.choices.map((c, i) => `
          <label>
            <input type="radio" name="${q.id}" value="${i}">
            ${c}
          </label>
        `).join("")}
      `;

      container.appendChild(div);
    });
  }

  function resetQuiz() {
    document.getElementById("result").innerHTML = "";
    document.getElementById("studentName").value = "";
    renderQuiz();
  }

  /***********************
   * 4) SUBMISSION LOGIC
   ***********************/
  function getStudentAnswers() {
    const answers = {};

    for (const q of quiz) {
      const selected = document.querySelector(`input[name="${q.id}"]:checked`);
      answers[q.id] = selected ? Number(selected.value) : null;
    }

    return answers;
  }

  function gradeAnswers(answers) {
    let correct = 0;

    for (const q of quiz) {
      if (answers[q.id] === q.answerIndex) correct++;
    }

    return {
      correct,
      total: quiz.length,
      percent: Math.round((correct / quiz.length) * 100)
    };
  }

  function submitQuiz() {
    const name = document.getElementById("studentName").value.trim();

    if (!name) {
      alert("Please enter your name.");
      return;
    }

    const answers = getStudentAnswers();

    // Prevent submitting with unanswered questions (optional)
    const unanswered = Object.values(answers).some(v => v === null);
    if (unanswered) {
      alert("Please answer all questions before submitting.");
      return;
    }

    const score = gradeAnswers(answers);

    const submission = {
      id: crypto.randomUUID(),
      studentName: name,
      timestamp: new Date().toISOString(),
      answers,     // stores the selected choice index per question
      score
    };

    addSubmission(submission);

    document.getElementById("result").innerHTML =
      `✅ Submitted! Score: <b>${score.correct}/${score.total}</b> (${score.percent}%)`;

    renderAdminTable();
  }

  /***********************
   * 5) ADMIN TABLE VIEW
   ***********************/
  function renderAdminTable() {
    const admin = document.getElementById("adminTable");
    const db = loadDB();

    if (db.length === 0) {
      admin.innerHTML = `<p class="muted">No submissions yet.</p>`;
      return;
    }

    const rows = db.map(sub => {
      const readableTime = new Date(sub.timestamp).toLocaleString();

      const answerText = quiz.map(q => {
        const chosen = sub.answers[q.id];
        const chosenText = chosen === null ? "(blank)" : q.choices[chosen];
        const correctText = q.choices[q.answerIndex];
        const ok = chosen === q.answerIndex;

        return `
          <div style="margin-bottom:6px;">
            <span class="pill">${q.id}</span>
            ${ok ? "✅" : "❌"} 
            <b>${chosenText}</b>
            <span class="muted"> (correct: ${correctText})</span>
          </div>
        `;
      }).join("");

      return `
        <tr>
          <td><b>${escapeHTML(sub.studentName)}</b></td>
          <td>${readableTime}</td>
          <td>${sub.score.correct}/${sub.score.total} (${sub.score.percent}%)</td>
          <td>${answerText}</td>
        </tr>
      `;
    }).join("");

    admin.innerHTML = `
      <table>
        <thead>
          <tr>
            <th>Student</th>
            <th>Time</th>
            <th>Score</th>
            <th>Answers</th>
          </tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
    `;
  }

  function escapeHTML(str) {
    return str
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }

  /***********************
   * 6) EXPORT / IMPORT
   ***********************/
  function exportJSON() {
    const db = loadDB();
    const blob = new Blob([JSON.stringify(db, null, 2)], { type: "application/json" });

    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "quiz_submissions.json";
    a.click();

    URL.revokeObjectURL(a.href);
  }

  function importJSON() {
    const input = document.getElementById("importFile");
    input.value = "";
    input.click();

    input.onchange = async () => {
      const file = input.files?.[0];
      if (!file) return;

      try {
        const text = await file.text();
        const parsed = JSON.parse(text);

        if (!Array.isArray(parsed)) {
          alert("Invalid file: expected an array.");
          return;
        }

        // Light validation
        for (const item of parsed) {
          if (!item.studentName || !item.timestamp || !item.answers || !item.score) {
            alert("Invalid file format (missing required fields).");
            return;
          }
        }

        saveDB(parsed);
        renderAdminTable();
        alert("Import successful.");
      } catch (e) {
        alert("Import failed: invalid JSON.");
      }
    };
  }

  /***********************
   * INIT
   ***********************/
  renderQuiz();
  renderAdminTable();
</script>