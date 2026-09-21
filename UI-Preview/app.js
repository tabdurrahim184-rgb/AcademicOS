// AcademicOS High-Fidelity Visual Preview Application
// Complete interactive prototype matching the native SwiftUI application

const state = {
    currentTab: 'command', // command, courses, calendar, ai, profile
    currentScreen: 'tab', // tab, course-detail, recording, transcript, intelligence, quiz, university
    activeCourseId: 'comm101',
    courseDetailTab: 'overview', // overview, notes, lectures, recordings, documents, exams, flashcards, ai
    notesSubMode: 'nokta', // full, study, nokta
    isOnline: true,
    isDarkMode: true,
    aiRoutingMode: 'automatic', // automatic, onlinePreferred, offlinePreferred, localOnly
    myMaterialsOnly: true,
    allowCloudAI: true,
    isRecording: true,
    recordingTimerSeconds: 4356, // 01:12:36
    recordingIntervalId: null,
    audioPlaybackTime: '00:37:16',
    activeQuizQuestion: 0,
    quizScore: 0,
    quizAnswered: {},
    quizFinished: false,
    activeSheet: null, // 'markers', 'ai-status', 'add-course', 'edit-card'
    selectedCardForEdit: null,
    
    // Telemetry stats
    telemetry: {
        geminiCalls: 18,
        appleLocalCalls: 42,
        ruleEngineCalls: 14,
        fallbacks: 2,
        quotaErrors: 0,
        avgLatencyMs: 320
    },

    // Interactive flashcards
    flashcardsDeck: [
        { id: 1, front: "Bourdieu'ye göre kültürel sermayenin 3 biçimi nedir?", back: "1. İçselleştirilmiş (Habitus)\n2. Nesneleşmiş (Kitap, sanat eseri)\n3. Kurumsallaşmış (Diploma, unvan)", type: "definition", flipped: false },
        { id: 2, front: "Habitus kavramının en kısa tanımı nedir?", back: "Geçmiş deneyimlerle oluşan, eylemlerimizi yönlendiren içselleştirilmiş yatkınlıklar sistemi.", type: "concept", flipped: false },
        { id: 3, front: "Basın özgürlüğü Anayasa'nın kaçıncı maddesindedir?", back: "Madde 28: 'Basın hürdür, sansür edilemez.'", type: "examHint", flipped: false }
    ],

    // Suggested cards with Accept / Edit / Reject
    suggestedCards: [
        { id: 101, front: "Kültürel sermaye ile sosyal sermaye arasındaki dönüşüm mekanizması nedir?", back: "Prestij ve unvanların sosyal ağlar ve ekonomik avantaja tahvil edilmesi.", type: "professorEmphasis" },
        { id: 102, front: "Alan (Champ) teorisinin temel dinamikleri nelerdir?", back: "Aktörlerin sermaye türlerini kullanarak tahakküm mücadelesi verdiği özerk sosyal mekanlar.", type: "concept" },
        { id: 103, front: "Doxa kavramı neyi ifade eder?", back: "Bir alanda sorgulanmaksızın doğru kabul edilen örtük inanç ve aksiyomlar bütünüdür.", type: "definition" }
    ],

    // Course AI Chat Messages
    chatMessages: [
        {
            id: 1,
            isUser: true,
            text: "Hoca final hakkında ne söyledi?"
        },
        {
            id: 2,
            isUser: false,
            providerBadge: "GEMINI",
            citation: "21 Eylül Dersi (00:37:16)",
            text: "Prof. Dr. Haluk Şahin derste açıkça belirtti:\n\n\"Arkadaşlar bu ayrımı final için özellikle bilin. Kültürel sermaye ile sosyal sermaye arasındaki dönüşüm mekanizması kesinlikle sınav sorusu olarak karşınıza gelecek.\"\n\n[Ders Materyali — COMM 101 Lecture Notes]"
        }
    ],

    // Audio Markers in Recording
    audioMarkers: [
        { time: "00:14:22", title: "Habitus Tanımı", type: "definition", badgeStyle: "emerald" },
        { time: "00:37:16", title: "Final Sınav Sorusu İpucu", type: "examHint", badgeStyle: "crimson" },
        { time: "00:52:10", title: "Ödev Konusu ve Teslim", type: "assignment", badgeStyle: "indigo" },
        { time: "01:05:40", title: "Kavram Karşılaştırma", type: "important", badgeStyle: "amber" }
    ]
};

// Course Data
const coursesData = {
    comm101: {
        id: 'comm101',
        code: 'COMM 101',
        name: 'İletişim Sosyolojisi',
        professor: 'Prof. Dr. Haluk Şahin',
        department: 'İletişim Fakültesi',
        schedule: 'Pazartesi 10:00 - 11:50',
        room: 'B-204',
        credits: 4,
        notesCount: 8,
        recordingsCount: 6,
        flashcardsCount: 24,
        nextExam: '19 Kasım 2026 (%40 Final Öncesi)',
        color: '#4F46E5'
    },
    law202: {
        id: 'law202',
        code: 'LAW 202',
        name: 'Medya Hukuku & Fikri Mülkiyet',
        professor: 'Doç. Dr. Selin Erdem',
        department: 'Hukuk Fakültesi',
        schedule: 'Çarşamba 13:00 - 15:50',
        room: 'C-101',
        credits: 3,
        notesCount: 5,
        recordingsCount: 4,
        flashcardsCount: 18,
        nextExam: '12 Kasım 2026 (%35 Vize)',
        color: '#06B6D4'
    },
    cs105: {
        id: 'cs105',
        code: 'CS 105',
        name: 'Veri Gazeteciliği & Kodlama',
        professor: 'Dr. Öğr. Üyesi Kerem Akın',
        department: 'Bilgisayar Mühendisliği',
        schedule: 'Cuma 14:00 - 16:50',
        room: 'Lab 3',
        credits: 4,
        notesCount: 6,
        recordingsCount: 5,
        flashcardsCount: 30,
        nextExam: '26 Kasım 2026 (%30 Proje)',
        color: '#10B981'
    },
    pols210: {
        id: 'pols210',
        code: 'POLS 210',
        name: 'Kamu Diplomasisi & Propaganda',
        professor: 'Prof. Dr. Tarık Zafer',
        department: 'Siyaset Bilimi',
        schedule: 'Perşembe 09:30 - 12:20',
        room: 'A-302',
        credits: 3,
        notesCount: 4,
        recordingsCount: 3,
        flashcardsCount: 15,
        nextExam: '03 Aralık 2026 (%40 Vize)',
        color: '#F59E0B'
    }
};

// Quiz Questions
const quizQuestions = [
    {
        question: "Pierre Bourdieu'nün teorisinde bireylerin sosyal alanda eylemlerini belirleyen, içselleştirilmiş yatkınlıklar sistemi hangisidir?",
        options: [
            "A) Habitus",
            "B) Doxa",
            "C) Sembolik Şiddet",
            "D) Kültürel Hegemonya"
        ],
        correct: 0,
        explanation: "Doğru cevap A'dır. Habitus, toplumsal yapıların bireyin zihninde ve bedeninde içselleştirilmiş yatkınlıklar matrisidir.",
        source: "COMM 101 Ders Notu — Bölüm 2"
    },
    {
        question: "Aşağıdakilerden hangisi 'Kurumsallaşmış Kültürel Sermaye' türüne doğrudan bir örnektir?",
        options: [
            "A) Nadide bir tablo koleksiyonu",
            "B) Üniversite diploması ve doktora unvanı",
            "C) Aileden gelen geniş tanıdık çevresi",
            "D) Doğuştan gelen dil konuşma aksanı"
        ],
        correct: 1,
        explanation: "Doğru cevap B'dir. Diplomalar, sertifikalar ve akademik unvanlar kurumsallaşmış kültürel sermayedir.",
        source: "COMM 101 Ders Kaydı (00:28:15)"
    },
    {
        question: "Hocanın derste 'kesinlikle sınav sorusudur' diyerek vurguladığı temel dönüşüm ilişkisi hangisidir?",
        options: [
            "A) Kültürel sermayenin sosyal ve ekonomik sermayeye tahvil edilmesi",
            "B) Yalnızca fiziksel gücün paraya çevrilmesi",
            "C) Medyanın tarafsızlık ilkesi",
            "D) Bürokrasi hiyerarşisi"
        ],
        correct: 0,
        explanation: "Doğru cevap A'dır. Hoca 00:37:16'da sermaye türleri arasındaki dönüşüm mekanizmasına kırmızı alarm vermiştir.",
        source: "21 Eylül Transkript (00:37:16)"
    },
    {
        question: "Anayasa Madde 28'e göre basın hürriyeti hakkında temel ilke nedir?",
        options: [
            "A) Basın hürdür, sansür edilemez",
            "B) Basın her koşulda önceden izin almalıdır",
            "C) Yalnızca basılı gazeteler hürdür",
            "D) Basın özgürlüğü mutlak olup hiçbir sınırlandırmaya tabi değildir"
        ],
        correct: 0,
        explanation: "Doğru cevap A'dır. Anayasa md. 28 açıkça 'Basın hürdür, sansür edilemez' hükmünü amirdir.",
        source: "LAW 202 Medya Hukuku"
    },
    {
        question: "Bir sosyal 'Alan' (Champ) içinde aktörlerin temel rekabet unsuru nedir?",
        options: [
            "A) O alanda geçerli olan sermaye türünü biriktirmek ve tahakküm kurmak",
            "B) Yalnızca yasalara uymak",
            "C) Alanı tamamen yok etmek",
            "D) Pasif şekilde beklemek"
        ],
        correct: 0,
        explanation: "Doğru cevap A'dır. Her alan kendine özgü bir oyun (illusio) ve sermaye dağılım mücadelesi barındırır.",
        source: "Sosyoloji Kuramları — Bölüm 4"
    }
];

// Helper: Format Seconds to HH:MM:SS
function formatTimer(totalSec) {
    const hours = Math.floor(totalSec / 3600);
    const minutes = Math.floor((totalSec % 3600) / 60);
    const seconds = totalSec % 60;
    const pad = (n) => String(n).padStart(2, '0');
    return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`;
}

// Global App Initializer
function initApp() {
    setupEventListeners();
    startLiveTimer();
    render();
}

function setupEventListeners() {
    // Outer Studio Controls
    document.getElementById('theme-toggle')?.addEventListener('click', toggleTheme);
    document.getElementById('network-toggle')?.addEventListener('click', toggleNetwork);
    document.getElementById('bezel-toggle')?.addEventListener('click', toggleBezel);
    document.getElementById('quick-jump')?.addEventListener('change', (e) => {
        handleQuickJump(e.target.value);
    });

    // Tab buttons
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const tab = btn.dataset.tab;
            if (tab) {
                switchTab(tab);
            }
        });
    });
}

// Live timer tick for realistic recording experience
function startLiveTimer() {
    if (state.recordingIntervalId) clearInterval(state.recordingIntervalId);
    state.recordingIntervalId = setInterval(() => {
        if (state.isRecording) {
            state.recordingTimerSeconds += 1;
            const timerEl = document.getElementById('live-recording-timer');
            if (timerEl) {
                timerEl.textContent = formatTimer(state.recordingTimerSeconds);
            }
        }
    }, 1000);
}

// State Modifiers
function toggleTheme() {
    state.isDarkMode = !state.isDarkMode;
    document.body.setAttribute('data-theme', state.isDarkMode ? 'dark' : 'light');
    const btn = document.getElementById('theme-toggle');
    if (btn) btn.textContent = state.isDarkMode ? '☀️ Light Mode' : '🌙 Dark Mode';
}

function toggleNetwork() {
    state.isOnline = !state.isOnline;
    const btn = document.getElementById('network-toggle');
    if (btn) {
        btn.textContent = state.isOnline ? '🌐 Online (Simulate Offline)' : '📵 Offline Active (Go Online)';
        btn.classList.toggle('active', !state.isOnline);
    }
    render();
}

function toggleBezel() {
    const frame = document.querySelector('.iphone-frame');
    if (frame) {
        frame.classList.toggle('no-bezel');
    }
}

function handleQuickJump(target) {
    switch (target) {
        case 'command':
            state.currentScreen = 'tab';
            state.currentTab = 'command';
            break;
        case 'courses':
            state.currentScreen = 'tab';
            state.currentTab = 'courses';
            break;
        case 'course-detail':
            state.currentScreen = 'course-detail';
            state.activeCourseId = 'comm101';
            state.courseDetailTab = 'overview';
            break;
        case 'recording':
            state.currentScreen = 'recording';
            break;
        case 'transcript':
            state.currentScreen = 'transcript';
            break;
        case 'intelligence':
            state.currentScreen = 'intelligence';
            break;
        case 'notes':
            state.currentScreen = 'course-detail';
            state.activeCourseId = 'comm101';
            state.courseDetailTab = 'notes';
            state.notesSubMode = 'nokta';
            break;
        case 'course-ai':
            state.currentScreen = 'course-detail';
            state.activeCourseId = 'comm101';
            state.courseDetailTab = 'ai';
            break;
        case 'exam-quiz':
            state.currentScreen = 'quiz';
            state.activeQuizQuestion = 0;
            state.quizFinished = false;
            break;
        case 'flashcards':
            state.currentScreen = 'course-detail';
            state.activeCourseId = 'comm101';
            state.courseDetailTab = 'flashcards';
            break;
        case 'calendar':
            state.currentScreen = 'tab';
            state.currentTab = 'calendar';
            break;
        case 'university':
            state.currentScreen = 'university';
            break;
        case 'ai-center':
            state.currentScreen = 'tab';
            state.currentTab = 'ai';
            break;
        case 'profile':
            state.currentScreen = 'tab';
            state.currentTab = 'profile';
            break;
    }
    render();
}

function switchTab(tabName) {
    state.currentTab = tabName;
    state.currentScreen = 'tab';
    render();
}

function openCourseDetail(courseId, subTab = 'overview') {
    state.activeCourseId = courseId;
    state.courseDetailTab = subTab;
    state.currentScreen = 'course-detail';
    render();
}

// Main Render Router
function render() {
    updateTopNavigationUI();
    const container = document.getElementById('viewport-content');
    if (!container) return;

    if (state.currentScreen === 'course-detail') {
        container.innerHTML = renderCourseDetailScreen();
    } else if (state.currentScreen === 'recording') {
        container.innerHTML = renderRecordingScreen();
    } else if (state.currentScreen === 'transcript') {
        container.innerHTML = renderTranscriptScreen();
    } else if (state.currentScreen === 'intelligence') {
        container.innerHTML = renderLectureIntelligenceScreen();
    } else if (state.currentScreen === 'quiz') {
        container.innerHTML = renderQuizScreen();
    } else if (state.currentScreen === 'university') {
        container.innerHTML = renderUniversityScreen();
    } else {
        // Tab router
        switch (state.currentTab) {
            case 'command':
                container.innerHTML = renderCommandDashboard();
                break;
            case 'courses':
                container.innerHTML = renderCoursesList();
                break;
            case 'calendar':
                container.innerHTML = renderCalendarScreen();
                break;
            case 'ai':
                container.innerHTML = renderAICommandCenter();
                break;
            case 'profile':
                container.innerHTML = renderProfileSettings();
                break;
        }
    }

    renderModals();
}

function updateTopNavigationUI() {
    // Update active tab button style
    document.querySelectorAll('.tab-btn').forEach(btn => {
        if (state.currentScreen === 'tab' && btn.dataset.tab === state.currentTab) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    });

    // Update status bar network indicator
    const wifiEl = document.getElementById('status-wifi');
    if (wifiEl) {
        wifiEl.textContent = state.isOnline ? '5G' : 'OFFLINE';
    }
}

// SCREEN 1: COMMAND DASHBOARD
function renderCommandDashboard() {
    const aiStatusKey = !state.isOnline ? "OFFLINE" : (state.aiRoutingMode === 'localOnly' ? "LOCAL RULE ENGINE" : "HYBRID AI");
    const badgeStyle = !state.isOnline ? "neutral" : (state.aiRoutingMode === 'localOnly' ? "emerald" : "indigo");

    return `
        <!-- Top Title -->
        <div class="ios-nav-header">
            <div class="nav-title-group">
                <span class="nav-pretitle">ACADEMICOS COMMAND</span>
                <h1 class="nav-main-title">Dashboard</h1>
            </div>
            <div class="nav-action-btn" onclick="openUniversityPortal()">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M12 2L1 7l11 5 9-4.09V17h2V7L12 2zm0 8.9L4.2 7 12 3.5 19.8 7 12 10.9zM4 10.8v6.4c0 3.3 3.6 6 8 6s8-2.7 8-6v-6.4l-8 3.6-8-3.6z"/>
                </svg>
            </div>
        </div>

        <!-- AI Router Status Banner -->
        <div class="academic-card card-clickable" onclick="openAIStatusSheet()" style="border-left: 4px solid var(--academic-primary);">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                <div style="display: flex; align-items: center; gap: 6px;">
                    <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--academic-primary);">AI ROUTER ENGINE</span>
                </div>
                <span class="status-badge badge-${badgeStyle}">${aiStatusKey}</span>
            </div>
            <p style="font-size: 12px; color: var(--text-secondary); line-height: 1.4;">
                ${state.isOnline 
                    ? "Hybrid intelligence active. Balances Apple on-device neural processing with Gemini Developer API free tier."
                    : "Offline mode active. All course notes, recordings, and local rule reasoning remain 100% available without network."
                }
            </p>
            <div style="display: flex; justify-content: space-between; margin-top: 8px; font-size: 10px; color: var(--text-tertiary); font-family: monospace;">
                <span>● ${state.isOnline ? "Network Live" : "Zero Cloud Packets"}</span>
                <span>Tap for Details ℹ️</span>
            </div>
        </div>

        <!-- Operation Graduation Hero Banner -->
        <div class="hero-graduation-card">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--academic-cyan);">OPERATION GRADUATION</span>
                <span class="status-badge badge-cyan">ON TRACK</span>
            </div>
            <div class="countdown-display">
                <span class="countdown-value">D-284</span>
                <span class="countdown-sub">30 Haziran 2027</span>
            </div>
            <div style="display: flex; justify-content: space-between; font-size: 11px; margin-bottom: 6px; color: var(--text-secondary);">
                <span>164 / 240 AKTS Tamamlandı</span>
                <span style="font-weight: 700; color: #FFF;">%68</span>
            </div>
            <div class="progress-track">
                <div class="progress-fill" style="width: 68%;"></div>
            </div>
        </div>

        <!-- Academic Status Metric Grid -->
        <div class="metric-grid-2">
            <div class="metric-card-box">
                <span class="metric-label">GENEL NOT ORTALAMASI</span>
                <span class="metric-val" style="color: var(--academic-primary); font-size: 20px;">3.42 GPA</span>
                <span style="font-size: 10px; color: var(--text-tertiary);">Hedef: 3.50+</span>
            </div>
            <div class="metric-card-box">
                <span class="metric-label">AKTİF DERS SAYISI</span>
                <span class="metric-val" style="font-size: 20px;">4 Ders</span>
                <span style="font-size: 10px; color: var(--academic-emerald);">Dönem: 2026 Güz</span>
            </div>
        </div>

        <!-- Today's Classes -->
        <div style="display: flex; justify-content: space-between; align-items: center; margin: 18px 0 8px;">
            <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--text-tertiary);">BUGÜNKÜ DERSLER</span>
            <span style="font-size: 11px; color: var(--academic-primary); font-weight: 600; cursor: pointer;" onclick="switchTab('calendar')">Tümü</span>
        </div>
        <div class="academic-card card-clickable" onclick="openCourseDetail('comm101')">
            <div style="display: flex; justify-content: space-between; align-items: flex-start;">
                <div>
                    <span style="font-size: 11px; font-weight: 700; color: var(--academic-primary);">COMM 101 • 10:00 - 11:50</span>
                    <h3 style="font-size: 15px; font-weight: 700; margin: 2px 0 4px;">İletişim Sosyolojisi</h3>
                    <p style="font-size: 12px; color: var(--text-secondary);">Derslik: B-204 • Prof. Dr. Haluk Şahin</p>
                </div>
                <button class="studio-btn" style="padding: 4px 8px; font-size: 11px; background: rgba(79, 70, 229, 0.2); color: var(--academic-secondary);" onclick="event.stopPropagation(); openRecordingStudio();">
                    🎙️ Derse Gir
                </button>
            </div>
        </div>

        <!-- Next Exam & Pending Missions -->
        <div style="display: flex; justify-content: space-between; align-items: center; margin: 18px 0 8px;">
            <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--text-tertiary);">YAKLAŞAN SINAV & TESLİMLER</span>
        </div>
        <div class="academic-card card-clickable" onclick="openCourseDetail('law202', 'exams')">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px;">
                <span class="status-badge badge-crimson">ARA SINAV (VİZE)</span>
                <span style="font-size: 11px; font-weight: 700; font-family: monospace; color: var(--academic-crimson);">52 GÜN KALDI</span>
            </div>
            <h4 style="font-size: 14px; font-weight: 700;">LAW 202: Medya Hukuku Vizesi</h4>
            <p style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;">Tarih: 12 Kasım 2026 • Ağırlık: %35</p>
        </div>

        <div class="academic-card card-clickable" onclick="openCourseDetail('comm101', 'notes')">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px;">
                <span class="status-badge badge-amber">ÖDEV TESLİMİ</span>
                <span style="font-size: 11px; font-weight: 700; font-family: monospace; color: var(--academic-amber);">3 GÜN KALDI</span>
            </div>
            <h4 style="font-size: 14px; font-weight: 700;">Habitus ve Sosyal Alan Analizi Raporu</h4>
            <p style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;">COMM 101 • Teslim: 24 Eylül 2026, 23:59</p>
        </div>
    `;
}

// SCREEN 2: COURSES LIST
function renderCoursesList() {
    return `
        <div class="ios-nav-header">
            <div class="nav-title-group">
                <span class="nav-pretitle">KAYITLI DERSLER</span>
                <h1 class="nav-main-title">Derslerim</h1>
            </div>
            <div class="nav-action-btn" onclick="openAddCourseSheet()">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z"/>
                </svg>
            </div>
        </div>

        <div style="display: flex; gap: 8px; margin-bottom: 14px;">
            <div class="academic-card" style="flex: 1; padding: 10px; margin-bottom: 0; text-align: center;">
                <span style="font-size: 10px; color: var(--text-tertiary); font-family: monospace;">TOPLAM DERS</span>
                <div style="font-size: 18px; font-weight: 800; color: #FFF;">4</div>
            </div>
            <div class="academic-card" style="flex: 1; padding: 10px; margin-bottom: 0; text-align: center;">
                <span style="font-size: 10px; color: var(--text-tertiary); font-family: monospace;">TOPLAM KREDİ</span>
                <div style="font-size: 18px; font-weight: 800; color: var(--academic-cyan);">15 AKTS</div>
            </div>
            <div class="academic-card" style="flex: 1; padding: 10px; margin-bottom: 0; text-align: center;">
                <span style="font-size: 10px; color: var(--text-tertiary); font-family: monospace;">AI BELLEK</span>
                <div style="font-size: 18px; font-weight: 800; color: var(--academic-emerald);">İZOLE</div>
            </div>
        </div>

        ${Object.values(coursesData).map(c => `
            <div class="academic-card card-clickable" onclick="openCourseDetail('${c.id}')" style="border-left: 4px solid ${c.color};">
                <div style="display: flex; justify-content: space-between; align-items: flex-start;">
                    <div>
                        <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: ${c.color};">${c.code} • ${c.credits} AKTS</span>
                        <h3 style="font-size: 16px; font-weight: 700; margin: 3px 0 4px;">${c.name}</h3>
                        <p style="font-size: 12px; color: var(--text-secondary);">${c.professor}</p>
                    </div>
                    <span class="status-badge badge-neutral">${c.room}</span>
                </div>
                <div style="display: flex; gap: 12px; margin-top: 12px; padding-top: 10px; border-top: 1px solid var(--border-subtle); font-size: 11px; color: var(--text-tertiary);">
                    <span>📝 ${c.notesCount} Not</span>
                    <span>🎙️ ${c.recordingsCount} Kayıt</span>
                    <span>🃏 ${c.flashcardsCount} Kart</span>
                </div>
            </div>
        `).join('')}
    `;
}

// SCREEN 3: COURSE DETAIL (WITH 8 SUB-TABS)
function renderCourseDetailScreen() {
    const course = coursesData[state.activeCourseId] || coursesData.comm101;

    return `
        <!-- Back Navigation -->
        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px;">
            <button class="studio-btn" style="padding: 4px 10px; font-size: 12px;" onclick="state.currentScreen = 'tab'; state.currentTab = 'courses'; render();">
                ← Dersler
            </button>
            <span class="status-badge badge-indigo">COURSE ISOLATED</span>
        </div>

        <div style="margin-bottom: 14px;">
            <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--academic-primary);">${course.code} • ${course.department}</span>
            <h1 style="font-size: 22px; font-weight: 800; margin: 2px 0 4px;">${course.name}</h1>
            <p style="font-size: 13px; color: var(--text-secondary);">${course.professor} • ${course.schedule} (${course.room})</p>
        </div>

        <!-- 8 Tabs Segmented Bar -->
        <div style="overflow-x: auto; padding-bottom: 6px; margin-bottom: 12px; -webkit-overflow-scrolling: touch;">
            <div class="segmented-control" style="width: max-content; min-width: 100%;">
                <div class="segment-item ${state.courseDetailTab === 'overview' ? 'active' : ''}" onclick="state.courseDetailTab = 'overview'; render();">Genel</div>
                <div class="segment-item ${state.courseDetailTab === 'notes' ? 'active' : ''}" onclick="state.courseDetailTab = 'notes'; render();">Notlar</div>
                <div class="segment-item ${state.courseDetailTab === 'lectures' ? 'active' : ''}" onclick="state.courseDetailTab = 'lectures'; render();">Dersler</div>
                <div class="segment-item ${state.courseDetailTab === 'recordings' ? 'active' : ''}" onclick="state.courseDetailTab = 'recordings'; render();">Kayıtlar</div>
                <div class="segment-item ${state.courseDetailTab === 'documents' ? 'active' : ''}" onclick="state.courseDetailTab = 'documents'; render();">Doküman</div>
                <div class="segment-item ${state.courseDetailTab === 'exams' ? 'active' : ''}" onclick="state.courseDetailTab = 'exams'; render();">Sınavlar</div>
                <div class="segment-item ${state.courseDetailTab === 'flashcards' ? 'active' : ''}" onclick="state.courseDetailTab = 'flashcards'; render();">Kartlar</div>
                <div class="segment-item ${state.courseDetailTab === 'ai' ? 'active' : ''}" onclick="state.courseDetailTab = 'ai'; render();">Ders AI</div>
            </div>
        </div>

        <!-- Sub-tab Content Renderer -->
        ${renderCourseSubTabContent(course)}
    `;
}

function renderCourseSubTabContent(course) {
    switch (state.courseDetailTab) {
        case 'overview':
            return `
                <div class="academic-card">
                    <h3 style="font-size: 14px; font-weight: 700; margin-bottom: 6px;">Ders İzlencesi & Amaç</h3>
                    <p style="font-size: 13px; color: var(--text-secondary); line-height: 1.5;">
                        Bu ders; iletişim teorilerini toplumsal yapılar, iktidar ilişkileri ve Pierre Bourdieu'nün alan/sermaye teorisi çerçevesinde inceler.
                    </p>
                </div>
                <div class="academic-card card-clickable" onclick="openRecordingStudio()">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <div>
                            <span class="status-badge badge-emerald">CANLI DERS KAYDI</span>
                            <h4 style="font-size: 15px; font-weight: 700; margin-top: 4px;">Ders Kayıt Stüdyosunu Başlat</h4>
                            <p style="font-size: 12px; color: var(--text-secondary);">Zaman damgalı hoca vurgusu yakalama</p>
                        </div>
                        <span style="font-size: 24px;">🎙️</span>
                    </div>
                </div>
                <div class="academic-card">
                    <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--text-tertiary);">DEĞERLENDİRME KRİTERLERİ</span>
                    <div style="margin-top: 8px; font-size: 13px; line-height: 1.8;">
                        <div style="display: flex; justify-content: space-between;"><span>Vize Sınavı</span><span style="font-weight: 700;">%35</span></div>
                        <div style="display: flex; justify-content: space-between;"><span>Dönem İçi Ödev & Vaka Analizi</span><span style="font-weight: 700;">%25</span></div>
                        <div style="display: flex; justify-content: space-between;"><span>Final Sınavı</span><span style="font-weight: 700;">%40</span></div>
                    </div>
                </div>
            `;

        case 'notes':
            return `
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
                    <div class="segmented-control" style="margin-bottom: 0; width: 100%;">
                        <div class="segment-item ${state.notesSubMode === 'full' ? 'active' : ''}" onclick="state.notesSubMode = 'full'; render();">Full Not</div>
                        <div class="segment-item ${state.notesSubMode === 'study' ? 'active' : ''}" onclick="state.notesSubMode = 'study'; render();">Çalışma</div>
                        <div class="segment-item ${state.notesSubMode === 'nokta' ? 'active' : ''}" onclick="state.notesSubMode = 'nokta'; render();">🎯 Nokta Atışı</div>
                    </div>
                </div>
                ${renderNotesContent()}
            `;

        case 'recordings':
            return `
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
                    <h3 style="font-size: 14px; font-weight: 700;">Ders Ses Kayıtları (6)</h3>
                    <button class="studio-btn" style="padding: 4px 10px; font-size: 11px; background: var(--academic-primary); color: #FFF;" onclick="openRecordingStudio()">
                        + Yeni Kayıt
                    </button>
                </div>
                <div class="academic-card card-clickable" onclick="openTranscriptScreen()">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <div>
                            <span class="status-badge badge-crimson">1 EXAM HINT IDENTIFIED</span>
                            <h4 style="font-size: 14px; font-weight: 700; margin: 4px 0 2px;">21 Eylül 2026 — Bourdieu ve Sermaye</h4>
                            <p style="font-size: 12px; color: var(--text-secondary);">Süre: 01:12:36 • %100 Transkribe Edildi</p>
                        </div>
                        <span style="font-size: 18px; color: var(--academic-primary);">➔</span>
                    </div>
                </div>
                <div class="academic-card card-clickable" onclick="openTranscriptScreen()">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <div>
                            <span class="status-badge badge-emerald">SENTETİZE EDİLDİ</span>
                            <h4 style="font-size: 14px; font-weight: 700; margin: 4px 0 2px;">14 Eylül 2026 — İletişim Sosyolojisine Giriş</h4>
                            <p style="font-size: 12px; color: var(--text-secondary);">Süre: 00:48:15 • Transkript Hazır</p>
                        </div>
                        <span style="font-size: 18px; color: var(--academic-primary);">➔</span>
                    </div>
                </div>
            `;

        case 'flashcards':
            return renderFlashcardsSection();

        case 'exams':
            return `
                <div class="academic-card">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <span class="status-badge badge-crimson">ARA SINAV (VİZE)</span>
                        <span style="font-weight: 800; font-family: monospace; color: var(--academic-crimson);">52 GÜN</span>
                    </div>
                    <h3 style="font-size: 16px; font-weight: 800; margin: 6px 0 4px;">Medya Hukuku Ara Sınavı</h3>
                    <p style="font-size: 12px; color: var(--text-secondary);">Kapsam: 1-6. Hafta Ders Notları, Makaleler ve Anayasa md. 26-28.</p>
                </div>
                <div class="academic-card">
                    <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--academic-primary);">EXAM AGENT PRACTICE TESTS</span>
                    <h4 style="font-size: 14px; font-weight: 700; margin: 4px 0 8px;">Ders Materyali Odaklı Alıştırma Simülasyonu</h4>
                    <p style="font-size: 12px; color: var(--text-secondary); margin-bottom: 12px;">
                        Exam Agent hoca vurgularını ve ders notlarını tarayarak alıştırma soruları üretir.
                    </p>
                    <div style="display: flex; gap: 8px;">
                        <button class="studio-btn" style="flex: 1; justify-content: center; background: var(--academic-primary); color: #FFF;" onclick="openQuizScreen(5)">
                            5 Soru Başlat
                        </button>
                        <button class="studio-btn" style="flex: 1; justify-content: center;" onclick="openQuizScreen(10)">
                            10 Soru
                        </button>
                        <button class="studio-btn" style="flex: 1; justify-content: center;" onclick="openQuizScreen(20)">
                            20 Soru
                        </button>
                    </div>
                </div>
            `;

        case 'ai':
            return renderCourseAIChat();

        default:
            return `<div class="academic-card"><p style="font-size: 13px; color: var(--text-secondary);">Bu sekme için içerik yüklendi.</p></div>`;
    }
}

// SCREEN 4: LECTURE RECORDING STUDIO (Timer, Waveform, Markers)
function renderRecordingScreen() {
    return `
        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px;">
            <button class="studio-btn" onclick="state.currentScreen = 'course-detail'; render();">
                ← Ders
            </button>
            <span class="status-badge badge-crimson" style="animation: pulse 1.5s infinite;">● KAYIT ALINIYOR</span>
        </div>

        <div class="recording-screen">
            <div style="text-align: center;">
                <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--academic-primary);">COMM 101 • İLETİŞİM SOSYOLOJİSİ</span>
                <h2 style="font-size: 18px; font-weight: 800; margin-top: 4px;">Pierre Bourdieu: Kültürel Sermaye</h2>
                <p style="font-size: 12px; color: var(--text-secondary);">Prof. Dr. Haluk Şahin • B-204</p>
            </div>

            <!-- Large Digital Timer -->
            <div style="text-align: center; margin: 16px 0;">
                <div class="recording-timer-large" id="live-recording-timer">
                    ${formatTimer(state.recordingTimerSeconds)}
                </div>
                <span style="font-size: 11px; color: var(--text-tertiary); font-family: monospace;">ÇEVRİMDIŞI YEREL KAYIT (SIFIR BULUT)</span>
            </div>

            <!-- Waveform Animation -->
            <div class="waveform-box">
                ${Array.from({ length: 32 }).map((_, i) => `
                    <div class="waveform-bar" style="animation-delay: ${(i * 0.04).toFixed(2)}s; height: ${15 + (i % 7) * 8}px;"></div>
                `).join('')}
            </div>

            <!-- Mark Important Action Button -->
            <button class="studio-btn" style="width: 100%; padding: 14px; font-size: 14px; font-weight: 800; background: rgba(239, 68, 68, 0.2); color: #F87171; border-color: rgba(239, 68, 68, 0.5); justify-content: center; margin-bottom: 12px;" onclick="openAudioMarkersSheet()">
                ⭐ HOCA VURGUSU EKLE (MARK IMPORTANT)
            </button>

            <!-- Recording Controls -->
            <div style="display: flex; gap: 10px; width: 100%; margin-bottom: 16px;">
                <button class="studio-btn" style="flex: 1; padding: 12px; justify-content: center;" onclick="state.isRecording = !state.isRecording; render();">
                    ${state.isRecording ? '⏸️ Duraklat' : '▶️ Devam Et'}
                </button>
                <button class="studio-btn" style="flex: 1; padding: 12px; justify-content: center; background: var(--academic-primary); color: #FFF;" onclick="openLectureIntelligenceResult()">
                    ⏹️ Kaydı Bitir & Analiz Et
                </button>
            </div>

            <!-- Placed Audio Markers List -->
            <div style="width: 100%;">
                <span style="font-size: 10px; font-weight: 800; font-family: monospace; color: var(--text-tertiary);">BU DERSTE EKLENEN VURGULAR (${state.audioMarkers.length})</span>
                <div style="max-height: 140px; overflow-y: auto; margin-top: 6px;">
                    ${state.audioMarkers.map(m => `
                        <div class="academic-card" style="padding: 8px 12px; margin-bottom: 6px; display: flex; justify-content: space-between; align-items: center;">
                            <div>
                                <span style="font-size: 11px; font-weight: 700; color: #FFF;">${m.title}</span>
                                <span style="font-size: 10px; color: var(--text-tertiary); display: block;">${m.time}</span>
                            </div>
                            <span class="status-badge badge-${m.badgeStyle}">${m.type}</span>
                        </div>
                    `).join('')}
                </div>
            </div>
        </div>
    `;
}

// SCREEN 5: TRANSCRIPT WITH HIGHLIGHT & JUMP-TO-AUDIO
function renderTranscriptScreen() {
    return `
        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px;">
            <button class="studio-btn" onclick="state.currentScreen = 'course-detail'; state.courseDetailTab = 'recordings'; render();">
                ← Kayıtlar
            </button>
            <button class="studio-btn" style="background: var(--academic-primary); color: #FFF; padding: 4px 10px; font-size: 11px;" onclick="openLectureIntelligenceResult()">
                AI Analizini Gör ➔
            </button>
        </div>

        <div style="margin-bottom: 14px;">
            <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--academic-primary);">21 EYLÜL 2026 DERSİ</span>
            <h2 style="font-size: 18px; font-weight: 800;">Ders Transkripti & Hoca Vurguları</h2>
            <p style="font-size: 12px; color: var(--text-secondary);">Ses Çalma Konumu: <b style="color: var(--academic-cyan); font-family: monospace;">${state.audioPlaybackTime}</b></p>
        </div>

        <!-- Segment 1 -->
        <div class="academic-card">
            <span style="font-size: 10px; font-weight: 800; font-family: monospace; color: var(--text-tertiary);">00:05:12</span>
            <p style="font-size: 13px; line-height: 1.5; color: var(--text-secondary); margin-top: 4px;">
                Günaydın arkadaşlar. Bugün Pierre Bourdieu'nün kültürel sermaye teorisini detaylandıracağız. Bildiğiniz gibi sermaye yalnızca parasal veya ekonomik varlıklardan ibaret değildir.
            </p>
        </div>

        <!-- Segment 2: EXPLICIT EXAM HINT (THE HERO EXAMPLE) -->
        <div class="academic-card" style="border: 2px solid var(--academic-crimson); background: rgba(239, 68, 68, 0.08);">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                <span class="status-badge badge-crimson">PROFESSOR EXPLICITLY MENTIONED EXAM</span>
                <button class="studio-btn" style="padding: 2px 8px; font-size: 10px; background: var(--academic-crimson); color: #FFF;" onclick="jumpToAudio('00:37:16')">
                    ▶ Sese Git (00:37:16)
                </button>
            </div>
            <p style="font-size: 14px; font-weight: 600; line-height: 1.5; color: #FFF;">
                "Arkadaşlar bu ayrımı final için özellikle bilin. Kültürel sermaye ile sosyal sermaye arasındaki dönüşüm mekanizması kesinlikle sınav sorusu olarak karşınıza gelecek."
            </p>
            <div style="display: flex; justify-content: space-between; margin-top: 8px; font-size: 10px; color: var(--text-tertiary); font-family: monospace;">
                <span>Zaman: 00:37:16 - 00:37:45</span>
                <span>Güven Skoru: %98 (Açık İfade)</span>
            </div>
        </div>

        <!-- Segment 3 -->
        <div class="academic-card">
            <span style="font-size: 10px; font-weight: 800; font-family: monospace; color: var(--text-tertiary);">00:52:10</span>
            <p style="font-size: 13px; line-height: 1.5; color: var(--text-secondary); margin-top: 4px;">
                Ödev tesliminde de bir gazete makalesini alıp oradaki kültürel kodları çözümlemenizi istiyorum. Gelecek hafta çarşambaya kadar sisteme yükleyin lütfen.
            </p>
            <div style="margin-top: 6px;">
                <span class="status-badge badge-indigo">ASSIGNMENT INSTRUCTION</span>
            </div>
        </div>
    `;
}

function jumpToAudio(timestamp) {
    state.audioPlaybackTime = timestamp;
    alert(`Ses çalma kafası doğrudan ${timestamp} zaman damgasına konumlandırıldı!`);
    render();
}

// SCREEN 6: LECTURE INTELLIGENCE RESULT SCREEN
function renderLectureIntelligenceScreen() {
    return `
        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px;">
            <button class="studio-btn" onclick="state.currentScreen = 'transcript'; render();">
                ← Transkript
            </button>
            <span class="status-badge badge-emerald">SYNTHESIS COMPLETE</span>
        </div>

        <div class="academic-card" style="background: linear-gradient(135deg, rgba(16, 185, 129, 0.15) 0%, rgba(79, 70, 229, 0.1) 100%); border-color: rgba(16, 185, 129, 0.4);">
            <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--academic-emerald);">YAPAY ZEKÂ DERS ANALİZİ</span>
            <h2 style="font-size: 18px; font-weight: 800; margin: 3px 0 4px;">21 Eylül Dersi: Bütüncül Sentez</h2>
            <p style="font-size: 12px; color: var(--text-secondary);">Hoca vurguları, kilit tanımlar ve sınav ipuçları başarıyla ayrıştırıldı.</p>
        </div>

        <!-- Executive Summary -->
        <div class="academic-card">
            <h3 style="font-size: 12px; font-weight: 800; font-family: monospace; color: var(--text-tertiary); margin-bottom: 6px;">ÖZET & TEMEL ARGÜMANLAR</h3>
            <p style="font-size: 13px; line-height: 1.5; color: var(--text-primary);">
                Derste Pierre Bourdieu'nün sermaye formları tartışılmış; kültürel sermayenin bedenselleşmiş (habitus), nesneleşmiş ve kurumsallaşmış (diploma) boyutları örneklendirilmiştir. Hoca, bu sermayenin sosyal sermayeye dönüşüm mantığına ve doxa kavramına özel vurgu yapmıştır.
            </p>
        </div>

        <!-- Key Topics -->
        <div class="academic-card">
            <h3 style="font-size: 12px; font-weight: 800; font-family: monospace; color: var(--text-tertiary); margin-bottom: 8px;">KİLİT KAVRAMLAR & TANIMLAR</h3>
            <div style="font-size: 13px; line-height: 1.6;">
                <p><b>• Habitus:</b> Bireyin toplumsal yapı içinde edindiği, eylemlerini üreten içselleşmiş yatkınlıklar bütünü.</p>
                <p style="margin-top: 6px;"><b>• Kültürel Sermaye:</b> Aileden ve eğitimden miras alınan kültürel bilgi ve yetkinlikler.</p>
                <p style="margin-top: 6px;"><b>• Alan (Champ):</b> Kendi kuralları ve sermaye dağılım mücadelesi olan özerk sosyal mekan.</p>
            </div>
        </div>

        <!-- Professor Emphasis Items -->
        <div class="academic-card" style="border-color: rgba(239, 68, 68, 0.4);">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                <span class="status-badge badge-crimson">KESİN SINAV İPUCU (00:37:16)</span>
            </div>
            <p style="font-size: 13px; font-weight: 600; color: #FFF;">
                "Kültürel sermaye ile sosyal sermaye arasındaki dönüşüm mekanizması kesinlikle sınav sorusu olarak karşınıza gelecek."
            </p>
        </div>

        <button class="studio-btn" style="width: 100%; padding: 12px; justify-content: center; background: var(--academic-primary); color: #FFF; font-weight: 700;" onclick="state.currentScreen = 'course-detail'; state.courseDetailTab = 'notes'; state.notesSubMode = 'nokta'; render();">
            🎯 Nokta Atışı Çalışma Notunu Gör
        </button>
    `;
}

// SCREEN 7: NOTES (FULL, STUDY, NOKTA ATIŞI)
function renderNotesContent() {
    if (state.notesSubMode === 'nokta') {
        return `
            <div class="academic-card" style="border: 2px solid var(--academic-primary); background: linear-gradient(135deg, rgba(79, 70, 229, 0.12) 0%, var(--bg-card) 100%);">
                <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
                    <span class="status-badge badge-indigo">🎯 NOKTA ATIŞI CRAM SHEET</span>
                    <span style="font-size: 11px; font-weight: 700; color: var(--academic-cyan);">5 DAKİKA TEKRARI</span>
                </div>
                <h2 style="font-size: 17px; font-weight: 800;">COMM 101: Sınav Öncesi Kritik Çerçeve</h2>
                <p style="font-size: 12px; color: var(--text-secondary);">Sınavda çıkması en muhtemel kavramlar, hoca uyarıları ve hızlı sorular.</p>
            </div>

            <!-- Top Must-Know Topics -->
            <div class="academic-card">
                <h3 style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--academic-primary); margin-bottom: 6px;">1. EN KRİTİK 3 KONU</h3>
                <ol style="padding-left: 18px; font-size: 13px; line-height: 1.6; color: var(--text-primary);">
                    <li>Bourdieu'nün 3 sermaye türü ve birbirine dönüşümü.</li>
                    <li>Habitus ile Alan arasındaki karşılıklı kurucu ilişki.</li>
                    <li>Sembolik şiddetin meşrulaştırılmasında eğitim kurumunun rolü.</li>
                </ol>
            </div>

            <!-- Explicit Exam Hint -->
            <div class="academic-card" style="border-left: 4px solid var(--academic-crimson);">
                <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
                    <span class="status-badge badge-crimson">HOCANIN SINAV İFADESİ</span>
                    <span style="font-size: 10px; font-family: monospace; color: var(--text-tertiary);">00:37:16</span>
                </div>
                <p style="font-size: 13px; font-weight: 600; color: #FFF;">
                    Sermaye dönüşüm formülü: "Kültürel sermaye sosyal ilişkiler yoluyla ekonomik sermayeye tahvil edilir."
                </p>
            </div>

            <!-- Common Confusions -->
            <div class="academic-card" style="border-left: 4px solid var(--academic-amber);">
                <span class="status-badge badge-amber">SIK YAPILAN KARIŞTIRMALAR</span>
                <p style="font-size: 13px; margin-top: 6px; line-height: 1.5;">
                    <b>Habitus ≠ Bilinçli Tercih:</b> Habitus otomatik ve düşünmeksizin verilen pratik yatkınlıktır, rasyonel bir hesaplama değildir.
                </p>
            </div>

            <!-- Quick Quiz Questions -->
            <div class="academic-card">
                <h3 style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--academic-cyan); margin-bottom: 6px;">HIZLI KONTROL SORULARI</h3>
                <div style="font-size: 13px; line-height: 1.6;">
                    <p><b>S1:</b> Diploma hangi sermayedir? <span style="color: var(--academic-emerald);">→ Kurumsallaşmış Kültürel.</span></p>
                    <p style="margin-top: 4px;"><b>S2:</b> Alanın içindeki örtük inanç nedir? <span style="color: var(--academic-emerald);">→ Doxa.</span></p>
                </div>
            </div>
        `;
    } else if (state.notesSubMode === 'study') {
        return `
            <div class="academic-card">
                <span class="status-badge badge-emerald">EXAM STUDY NOTES</span>
                <h3 style="font-size: 15px; font-weight: 700; margin: 4px 0 6px;">Kavram Karşılaştırma & Analiz Notu</h3>
                <p style="font-size: 13px; color: var(--text-secondary); line-height: 1.5;">
                    Bourdieu ile Foucault'nun iktidar tanımları arasındaki temel farklar: Foucault iktidarı her yerde ve ilişkisel görürken, Bourdieu alandaki sermaye birikimi üzerinden açıklar.
                </p>
            </div>
        `;
    } else {
        return `
            <div class="academic-card">
                <span class="status-badge badge-neutral">FULL LECTURE RECONSTRUCTION</span>
                <h3 style="font-size: 15px; font-weight: 700; margin: 4px 0 6px;">21 Eylül Dersi Tam Notları (12 Sayfa)</h3>
                <p style="font-size: 13px; color: var(--text-secondary); line-height: 1.5;">
                    Dersin girişinde hocanın yaptığı hatırlatmalar, öğrencilerin sorduğu sorular ve slaytlarda yer alan grafiksel analizlerin tam metin dökümü yer almaktadır.
                </p>
            </div>
        `;
    }
}

// SCREEN 8: COURSE AI CHAT
function renderCourseAIChat() {
    return `
        <!-- AI Settings Banner -->
        <div class="academic-card" style="padding: 12px; margin-bottom: 12px; background: rgba(79, 70, 229, 0.08); border-color: rgba(79, 70, 229, 0.25);">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <div>
                    <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--academic-primary);">MY MATERIALS ONLY</span>
                    <p style="font-size: 11px; color: var(--text-secondary);">Yalnızca bu dersin kayıt ve notlarından cevapla</p>
                </div>
                <input type="checkbox" id="materials-toggle" ${state.myMaterialsOnly ? 'checked' : ''} onchange="state.myMaterialsOnly = this.checked; render();" style="width: 20px; height: 20px; accent-color: var(--academic-primary); cursor: pointer;">
            </div>
            <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 8px; padding-top: 6px; border-top: 1px solid var(--border-subtle);">
                <span style="font-size: 11px; color: var(--text-tertiary);">Bulut Yapay Zekâ İzni: <b>${state.allowCloudAI ? 'AÇIK (Gemini)' : 'KAPALI (Yerel)'}</b></span>
                <span class="status-badge ${state.isOnline ? 'badge-indigo' : 'badge-emerald'}">${state.isOnline ? 'GEMINI READY' : 'LOCAL AI'}</span>
            </div>
        </div>

        <!-- Chat History -->
        <div style="display: flex; flex-direction: column; gap: 10px; margin-bottom: 16px;">
            ${state.chatMessages.map(msg => `
                <div style="display: flex; justify-content: ${msg.isUser ? 'flex-end' : 'flex-start'};">
                    <div style="max-width: 86%; padding: 12px 14px; border-radius: 16px; background: ${msg.isUser ? 'var(--academic-primary)' : 'var(--bg-card)'}; color: #FFF; border: ${msg.isUser ? 'none' : '1px solid var(--border-subtle)'};">
                        ${!msg.isUser && msg.providerBadge ? `
                            <div style="display: flex; align-items: center; gap: 6px; margin-bottom: 6px;">
                                <span class="status-badge ${msg.providerBadge === 'GEMINI' ? 'badge-indigo' : 'badge-emerald'}" style="font-size: 9px; padding: 2px 6px;">${msg.providerBadge}</span>
                                ${msg.citation ? `<span style="font-size: 10px; font-family: monospace; color: var(--academic-cyan);">${msg.citation}</span>` : ''}
                            </div>
                        ` : ''}
                        <p style="font-size: 13px; line-height: 1.45; white-space: pre-line;">${msg.text}</p>
                    </div>
                </div>
            `).join('')}
        </div>

        <!-- Input Bar -->
        <div style="display: flex; gap: 8px; align-items: center;">
            <input type="text" id="course-ai-input" placeholder="Ders hakkında sor (örn: Final sorusu neydi?)..." style="flex: 1; padding: 12px 14px; background: var(--bg-card); border: 1px solid var(--border-subtle); border-radius: 12px; color: #FFF; font-size: 13px; outline: none;" onkeydown="if(event.key === 'Enter') sendChatMessage();">
            <button class="studio-btn" style="padding: 12px 16px; background: var(--academic-primary); color: #FFF;" onclick="sendChatMessage()">
                Gönder
            </button>
        </div>
    `;
}

function sendChatMessage() {
    const input = document.getElementById('course-ai-input');
    if (!input || !input.value.trim()) return;

    const query = input.value.trim();
    state.chatMessages.push({ id: Date.now(), isUser: true, text: query });
    input.value = '';
    render();

    // AI Simulated Grounded Response
    setTimeout(() => {
        let reply = "";
        let citation = null;

        if (state.myMaterialsOnly) {
            if (query.toLowerCase().includes("final") || query.toLowerCase().includes("sınav")) {
                reply = "21 Eylül Transkripti (00:37:16):\n\"Kültürel sermaye ile sosyal sermaye arasındaki dönüşüm mekanizması kesinlikle sınav sorusu olarak karşınıza gelecek.\"\n\n[Grounded in COMM 101 Lecture Notes]";
                citation = "21 Eylül Dersi 00:37:16";
            } else {
                reply = "Ders notlarında ve kayıtlarında bu konuyla ilgili doğrudan bir hoca vurgusu tespit edildi: Habitus ve alan karşılıklı olarak birbirini inşa eden iki temel boyuttur.\n\n[Ders Materyali — COMM 101]";
                citation = "COMM 101 Bölüm 2";
            }
        } else {
            reply = "[Ders Materyali]\nHoca derste konuyu Bourdieu üzerinden açıkladı.\n\n[Ek Akademik Açıklama]\nGenel sosyoloji literatüründe bu teoriye yönelik en temel eleştiri, bireysel failliği yapı karşısında pasifleştirdiği yönündedir.";
            citation = "General AI Knowledge";
        }

        state.chatMessages.push({
            id: Date.now() + 1,
            isUser: false,
            providerBadge: state.isOnline ? "GEMINI" : "LOCAL AI",
            citation: citation,
            text: reply
        });
        render();
    }, 400);
}

// SCREEN 9: FLASHCARDS (ACCEPT, EDIT, REJECT WORKFLOW)
function renderFlashcardsSection() {
    return `
        <!-- Accepted Study Deck -->
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
            <h3 style="font-size: 14px; font-weight: 800;">Aktif Çalışma Destesi (${state.flashcardsDeck.length} Kart)</h3>
            <span style="font-size: 11px; color: var(--academic-emerald); font-weight: 700;">Spaced Repetition</span>
        </div>

        <div style="display: flex; flex-direction: column; gap: 10px; margin-bottom: 20px;">
            ${state.flashcardsDeck.map(card => `
                <div class="academic-card card-clickable" onclick="flipFlashcard(${card.id})" style="border-left: 4px solid var(--academic-emerald);">
                    <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
                        <span class="status-badge badge-emerald">${card.type.toUpperCase()}</span>
                        <span style="font-size: 10px; color: var(--text-tertiary);">Karta dokun (Çevir) 🔄</span>
                    </div>
                    <p style="font-size: 14px; font-weight: 700; color: #FFF; margin-top: 4px;">${card.flipped ? card.back : card.front}</p>
                </div>
            `).join('')}
        </div>

        <!-- AI Suggestions: Accept / Edit / Reject -->
        <div style="border-top: 1px solid var(--border-prominent); padding-top: 14px;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
                <h3 style="font-size: 14px; font-weight: 800; color: var(--academic-amber);">AI Kart Önerileri (${state.suggestedCards.length})</h3>
                <span class="status-badge badge-amber">ONAY BEKLİYOR</span>
            </div>
            <p style="font-size: 11px; color: var(--text-secondary); margin-bottom: 12px;">
                Kartlar onaylanana kadar desteye eklenmez. Kartları doğrudan kabul edebilir, düzenleyebilir veya reddedebilirsiniz.
            </p>

            ${state.suggestedCards.length === 0 ? `
                <div class="academic-card" style="text-align: center; padding: 20px;">
                    <p style="font-size: 13px; color: var(--text-secondary);">Bekleyen öneri bulunmuyor. Tüm kartlar incelendi!</p>
                </div>
            ` : state.suggestedCards.map(s => `
                <div class="academic-card" style="border: 1px dashed var(--academic-amber); background: rgba(245, 158, 11, 0.05); margin-bottom: 12px;">
                    <span style="font-size: 10px; font-weight: 800; color: var(--academic-amber); font-family: monospace;">ÖNERİLEN SORU</span>
                    <p style="font-size: 13px; font-weight: 700; margin: 4px 0 8px;">${s.front}</p>
                    <span style="font-size: 10px; font-weight: 800; color: var(--text-tertiary); font-family: monospace;">CEVAP</span>
                    <p style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;">${s.back}</p>
                    <div style="display: flex; gap: 8px; margin-top: 12px;">
                        <button class="studio-btn" style="flex: 1; justify-content: center; background: rgba(16, 185, 129, 0.2); color: #34D399; border-color: rgba(16, 185, 129, 0.4);" onclick="acceptCard(${s.id})">
                            ✓ Kabul Et
                        </button>
                        <button class="studio-btn" style="flex: 1; justify-content: center;" onclick="openEditCardSheet(${s.id})">
                            ✏️ Düzenle
                        </button>
                        <button class="studio-btn" style="flex: 1; justify-content: center; color: var(--academic-crimson);" onclick="rejectCard(${s.id})">
                            ✕ Reddet
                        </button>
                    </div>
                </div>
            `).join('')}
        </div>
    `;
}

function flipFlashcard(id) {
    const card = state.flashcardsDeck.find(c => c.id === id);
    if (card) {
        card.flipped = !card.flipped;
        render();
    }
}

function acceptCard(id) {
    const idx = state.suggestedCards.findIndex(s => s.id === id);
    if (idx !== -1) {
        const item = state.suggestedCards.splice(idx, 1)[0];
        state.flashcardsDeck.unshift({
            id: Date.now(),
            front: item.front,
            back: item.back,
            type: item.type,
            flipped: false
        });
        render();
    }
}

function rejectCard(id) {
    state.suggestedCards = state.suggestedCards.filter(s => s.id !== id);
    render();
}

function openEditCardSheet(id) {
    state.selectedCardForEdit = state.suggestedCards.find(s => s.id === id);
    state.activeSheet = 'edit-card';
    render();
}

// SCREEN 10: INTERACTIVE QUIZ & MASTERY
function renderQuizScreen() {
    if (state.quizFinished) {
        const pct = Math.round((state.quizScore / quizQuestions.length) * 100);
        return `
            <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px;">
                <button class="studio-btn" onclick="state.currentScreen = 'course-detail'; state.courseDetailTab = 'exams'; render();">
                    ← Sınavlara Dön
                </button>
                <span class="status-badge badge-emerald">TEST TAMAMLANDI</span>
            </div>

            <div class="academic-card" style="text-align: center; padding: 24px;">
                <span style="font-size: 48px;">🏆</span>
                <h2 style="font-size: 24px; font-weight: 800; margin: 8px 0 4px;">Tebrikler!</h2>
                <div style="font-size: 32px; font-weight: 900; font-family: monospace; color: var(--academic-primary); margin: 6px 0;">
                    %${pct} Başarı
                </div>
                <p style="font-size: 13px; color: var(--text-secondary);">5 sorudan ${state.quizScore} tanesini doğru yanıtladınız.</p>
            </div>

            <div class="academic-card">
                <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--academic-emerald);">DETERMİNİSTİK HAKİMİYET GÜNCELLEMESİ</span>
                <div style="margin-top: 8px; font-size: 13px; line-height: 1.6;">
                    <p><b>• Kültürel Sermaye Türleri:</b> Hakimiyet %85'e yükseldi (Güçlü Alan).</p>
                    <p style="margin-top: 4px;"><b>• Alan & Doxa Analizi:</b> Tekrar önerilir (Hakimiyet %55).</p>
                </div>
            </div>

            <button class="studio-btn" style="width: 100%; padding: 14px; justify-content: center; background: var(--academic-primary); color: #FFF; font-weight: 700;" onclick="state.quizFinished = false; state.activeQuizQuestion = 0; state.quizScore = 0; state.quizAnswered = {}; render();">
                Tekrar Test Yap
            </button>
        `;
    }

    const q = quizQuestions[state.activeQuizQuestion];
    const selectedOption = state.quizAnswered[state.activeQuizQuestion];
    const hasAnswered = selectedOption !== undefined;

    return `
        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px;">
            <button class="studio-btn" onclick="state.currentScreen = 'course-detail'; state.courseDetailTab = 'exams'; render();">
                ✕ Çıkış
            </button>
            <span style="font-size: 12px; font-weight: 700; font-family: monospace; color: var(--text-tertiary);">
                SORU ${state.activeQuizQuestion + 1} / ${quizQuestions.length}
            </span>
        </div>

        <div class="academic-card" style="margin-bottom: 14px;">
            <span class="status-badge badge-indigo">ALISTIRMA SORUSU</span>
            <h3 style="font-size: 15px; font-weight: 700; line-height: 1.45; margin-top: 8px;">${q.question}</h3>
        </div>

        <div>
            ${q.options.map((opt, idx) => {
                let cls = "";
                if (hasAnswered) {
                    if (idx === q.correct) cls = "correct";
                    else if (idx === selectedOption) cls = "incorrect";
                }
                return `
                    <div class="quiz-option-card ${cls}" onclick="answerQuizQuestion(${idx})">
                        <span style="font-size: 13px; font-weight: 600; color: #FFF;">${opt}</span>
                    </div>
                `;
            }).join('')}
        </div>

        ${hasAnswered ? `
            <div class="academic-card" style="border-left: 4px solid ${selectedOption === q.correct ? 'var(--academic-emerald)' : 'var(--academic-crimson)'};">
                <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: ${selectedOption === q.correct ? 'var(--academic-emerald)' : 'var(--academic-crimson)'};">
                    ${selectedOption === q.correct ? '✓ DOĞRU CEVAP' : '✕ YANLIŞ CEVAP'}
                </span>
                <p style="font-size: 12px; color: var(--text-primary); margin-top: 4px; line-height: 1.4;">${q.explanation}</p>
                <span style="font-size: 10px; font-family: monospace; color: var(--text-tertiary); display: block; margin-top: 4px;">Kaynak: ${q.source}</span>
            </div>

            <button class="studio-btn" style="width: 100%; padding: 12px; justify-content: center; background: var(--academic-primary); color: #FFF; font-weight: 700;" onclick="nextQuizQuestion()">
                ${state.activeQuizQuestion + 1 < quizQuestions.length ? 'Sonraki Soru ➔' : 'Sonuçları Gör 🏆'}
            </button>
        ` : ''}
    `;
}

function answerQuizQuestion(optionIndex) {
    if (state.quizAnswered[state.activeQuizQuestion] !== undefined) return;
    state.quizAnswered[state.activeQuizQuestion] = optionIndex;
    if (optionIndex === quizQuestions[state.activeQuizQuestion].correct) {
        state.quizScore += 1;
    }
    render();
}

function nextQuizQuestion() {
    if (state.activeQuizQuestion + 1 < quizQuestions.length) {
        state.activeQuizQuestion += 1;
    } else {
        state.quizFinished = true;
    }
    render();
}

// SCREEN 11: CALENDAR
function renderCalendarScreen() {
    return `
        <div class="ios-nav-header">
            <div class="nav-title-group">
                <span class="nav-pretitle">AKADEMİK TAKVİM</span>
                <h1 class="nav-main-title">Takvim</h1>
            </div>
            <div class="nav-action-btn">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M19 4h-1V2h-2v2H8V2H6v2H5c-1.11 0-1.99.9-1.99 2L3 20c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 16H5V10h14v10zm0-12H5V6h14v2z"/>
                </svg>
            </div>
        </div>

        <!-- Month Navigation Overview -->
        <div class="academic-card">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px;">
                <h3 style="font-size: 15px; font-weight: 800;">Eylül 2026</h3>
                <span style="font-size: 11px; font-family: monospace; color: var(--academic-cyan);">GÜZ DÖNEMİ</span>
            </div>
            <!-- 7 Days Grid -->
            <div style="display: grid; grid-template-columns: repeat(7, 1fr); text-align: center; gap: 4px; font-size: 11px; font-weight: 700; color: var(--text-tertiary); margin-bottom: 6px;">
                <span>Pt</span><span>Sa</span><span>Ça</span><span>Pe</span><span>Cu</span><span>Ct</span><span>Pz</span>
            </div>
            <div style="display: grid; grid-template-columns: repeat(7, 1fr); text-align: center; gap: 4px; font-size: 13px;">
                <span style="color: var(--text-tertiary);">31</span><span>1</span><span>2</span><span>3</span><span>4</span><span>5</span><span>6</span>
                <span>7</span><span>8</span><span>9</span><span>10</span><span>11</span><span>12</span><span>13</span>
                <span>14</span><span>15</span><span>16</span><span>17</span><span>18</span><span>19</span><span>20</span>
                <span style="background: var(--academic-primary); color: #FFF; border-radius: 50%; width: 28px; height: 28px; line-height: 28px; margin: 0 auto; font-weight: 800;">21</span>
                <span>22</span><span>23</span><span style="border-bottom: 2px solid var(--academic-amber);">24</span><span>25</span><span>26</span><span>27</span>
                <span>28</span><span>29</span><span>30</span><span style="color: var(--text-tertiary);">1</span><span style="color: var(--text-tertiary);">2</span>
            </div>
        </div>

        <!-- Event Categories -->
        <div style="display: flex; gap: 6px; overflow-x: auto; padding-bottom: 4px; margin-bottom: 12px;">
            <span class="status-badge badge-indigo">Class (Ders)</span>
            <span class="status-badge badge-crimson">Exam (Sınav)</span>
            <span class="status-badge badge-amber">Assignment (Ödev)</span>
            <span class="status-badge badge-emerald">Study (Tekrar)</span>
            <span class="status-badge badge-cyan">University</span>
        </div>

        <!-- Today's Schedule -->
        <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--text-tertiary);">BUGÜN (21 EYLÜL 2026)</span>
        <div class="academic-card" style="margin-top: 6px;">
            <div style="display: flex; justify-content: space-between;">
                <span style="font-size: 11px; font-weight: 700; color: var(--academic-primary);">10:00 - 11:50</span>
                <span class="status-badge badge-indigo">DERS</span>
            </div>
            <h4 style="font-size: 14px; font-weight: 700; margin-top: 2px;">COMM 101: İletişim Sosyolojisi</h4>
            <p style="font-size: 12px; color: var(--text-secondary);">B-204 • Prof. Dr. Haluk Şahin</p>
        </div>

        <!-- Upcoming -->
        <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--text-tertiary); margin-top: 14px; display: block;">YAKLAŞAN GÖREVLER</span>
        <div class="academic-card" style="margin-top: 6px;">
            <div style="display: flex; justify-content: space-between;">
                <span style="font-size: 11px; font-weight: 700; color: var(--academic-amber);">24 Eylül 2026, 23:59</span>
                <span class="status-badge badge-amber">ÖDEV</span>
            </div>
            <h4 style="font-size: 14px; font-weight: 700; margin-top: 2px;">Habitus & Sosyal Alan Raporu</h4>
            <p style="font-size: 12px; color: var(--text-secondary);">COMM 101 • 3 gün kaldı</p>
        </div>
    `;
}

// SCREEN 12: NEAR EAST UNIVERSITY INTEGRATION PORTAL (PHASE 2F)
function renderUniversityScreen() {
    return `
        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 10px;">
            <button class="studio-btn" onclick="state.currentScreen = 'tab'; state.currentTab = 'command'; render();">
                ← Dashboard
            </button>
            <span class="status-badge badge-amber" style="font-size: 8px;">AWAITING LIVE VALIDATION</span>
        </div>

        <div style="background: rgba(147, 51, 234, 0.12); border: 1px solid rgba(147, 51, 234, 0.3); border-radius: 8px; padding: 6px 10px; margin-bottom: 8px; font-size: 10px; font-family: monospace; color: #A855F7; display: flex; justify-content: space-between;">
            <span>PHASE 2F LIVE WEBKIT PIPELINE</span>
            <span>ZERO PASSWORDS IN CODE</span>
        </div>

        <!-- Stale Data Warning Indicator -->
        <div style="background: var(--bg-card-secondary); border-radius: 6px; padding: 6px 10px; margin-bottom: 10px; font-size: 10px; font-family: monospace; color: var(--text-secondary); display: flex; align-items: center; gap: 6px;">
            <span>🕒</span>
            <span>Son senkronizasyon: <b>18 saat önce</b> (Offline Cached)</span>
        </div>

        <!-- University Header Card -->
        <div class="academic-card" style="background: linear-gradient(135deg, rgba(147, 51, 234, 0.15) 0%, var(--bg-card) 100%);">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: #A855F7;">NEAR EAST UNIVERSITY</span>
                <span style="font-size: 9px; font-weight: 800; font-family: monospace; background: rgba(147, 51, 234, 0.2); color: #C084FC; padding: 2px 6px; border-radius: 4px;">YAKIN DOĞU</span>
            </div>
            <h2 style="font-size: 18px; font-weight: 800; margin: 4px 0 2px;">Öğrenci Portalı & DEBİM LMS</h2>
            <p style="font-size: 12px; color: var(--text-secondary);">Genius Student 2.0.0 (OBS) + Moodle E-Öğrenme</p>
            <div style="margin-top: 8px; font-size: 10px; font-family: monospace; color: var(--text-tertiary);">
                Selector Profili: <b>v2.6.0</b> (Live Learning Active)
            </div>
        </div>

        <!-- Dual System Status Grid -->
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-bottom: 10px;">
            <!-- DEBİM Moodle LMS -->
            <div class="academic-card" style="padding: 10px; border-top: 3px solid #3B82F6;">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: #60A5FA;">DEBİM LMS</span>
                    <span style="font-size: 8px; font-weight: 800; background: rgba(16, 185, 129, 0.2); color: #34D399; padding: 2px 4px; border-radius: 4px;">AUTHENTICATED</span>
                </div>
                <div style="font-size: 10px; font-family: monospace; color: var(--text-tertiary); margin: 3px 0;">debim.neu.edu.tr</div>
                <div style="font-size: 10px; color: #10B981; font-weight: 600;">Manual Google SAML</div>
                <button class="studio-btn" style="width: 100%; margin-top: 8px; padding: 6px; justify-content: center; font-size: 10px; font-weight: 700; color: #60A5FA; background: rgba(59, 130, 246, 0.15);" onclick="alert('DEBİM Moodle paneli izole WKWebView oturumunda açılıyor: https://debim.neu.edu.tr/login/index.php')">
                    OPEN DEBİM
                </button>
            </div>

            <!-- Student Portal OBS -->
            <div class="academic-card" style="padding: 10px; border-top: 3px solid #A855F7;">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: #C084FC;">OBS PORTALI</span>
                    <span style="font-size: 8px; font-weight: 800; background: rgba(16, 185, 129, 0.2); color: #34D399; padding: 2px 4px; border-radius: 4px;">AUTHENTICATED</span>
                </div>
                <div style="font-size: 10px; font-family: monospace; color: var(--text-tertiary); margin: 3px 0;">register.neu.edu.tr</div>
                <div style="font-size: 10px; color: var(--text-secondary); font-weight: 600;">Genius Student 2.0</div>
                <button class="studio-btn" style="width: 100%; margin-top: 8px; padding: 6px; justify-content: center; font-size: 10px; font-weight: 700; color: #C084FC; background: rgba(168, 85, 247, 0.15);" onclick="alert('Öğrenci Portalı tam eşleşen HTTPS host ile açılıyor: https://register.neu.edu.tr/Login/Login')">
                    OPEN PORTAL
                </button>
            </div>
        </div>

        <!-- Master Action Buttons -->
        <div style="display: flex; gap: 8px; margin-bottom: 8px;">
            <button class="studio-btn" style="flex: 1; justify-content: center; background: var(--academic-primary); color: #FFF; padding: 10px; font-weight: 700; font-family: monospace;" onclick="simulateNEUSyncAll()">
                🔄 SYNC ALL (DUAL)
            </button>
            <button class="studio-btn" style="flex: 1; justify-content: center; padding: 10px; font-weight: 700; font-family: monospace; color: #F59E0B; background: rgba(245, 158, 11, 0.12);" onclick="simulateDiagnosticsModal()">
                🛠️ DIAGNOSTICS
            </button>
        </div>

        <!-- Quick Sub-Actions -->
        <div style="display: flex; gap: 8px; margin-bottom: 10px;">
            <button class="studio-btn" style="flex: 1; justify-content: center; padding: 8px; font-weight: 700; font-size: 11px; font-family: monospace; color: #C084FC; background: rgba(168, 85, 247, 0.12);" onclick="simulateTranscriptPreview()">
                📄 TRANSCRIPT PREVIEW
            </button>
            <button class="studio-btn" style="flex: 1; justify-content: center; padding: 8px; font-weight: 700; font-size: 11px; font-family: monospace; color: #60A5FA; background: rgba(59, 130, 246, 0.12);" onclick="simulateMaterialImport()">
                📥 MATERIALS IMPORT
            </button>
        </div>

        <!-- Provenance Legend Pill Row -->
        <div class="academic-card" style="padding: 8px 12px; margin-bottom: 10px;">
            <span style="font-size: 9px; font-weight: 800; font-family: monospace; color: var(--text-tertiary); display: block; margin-bottom: 4px;">VERİ KAYNAĞI PROVENANCE ETİKETLERİ:</span>
            <div style="display: flex; gap: 6px; flex-wrap: wrap;">
                <span style="font-size: 9px; font-weight: 800; font-family: monospace; background: rgba(59, 130, 246, 0.2); color: #60A5FA; padding: 2px 6px; border-radius: 4px;">DEBİM</span>
                <span style="font-size: 9px; font-weight: 800; font-family: monospace; background: rgba(168, 85, 247, 0.2); color: #C084FC; padding: 2px 6px; border-radius: 4px;">NEU STUDENT PORTAL</span>
                <span style="font-size: 9px; font-weight: 800; font-family: monospace; background: rgba(245, 158, 11, 0.2); color: #FBBF24; padding: 2px 6px; border-radius: 4px;">MANUAL</span>
                <span style="font-size: 9px; font-weight: 800; font-family: monospace; background: rgba(16, 185, 129, 0.2); color: #34D399; padding: 2px 6px; border-radius: 4px;">AI DERIVED</span>
            </div>
        </div>

        <!-- Discrepancies Card -->
        <div class="academic-card" style="border-left: 4px solid #F59E0B; margin-bottom: 10px;">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <span style="font-size: 10px; font-weight: 800; font-family: monospace; color: #F59E0B;">⚠️ UYUMSUZLUK (1 CONFLICT)</span>
                <span style="font-size: 9px; font-weight: 800; font-family: monospace; color: var(--text-tertiary);">CENG 311</span>
            </div>
            <div style="margin-top: 6px; font-size: 11px; line-height: 1.4;">
                <div><b>Portal (Resmi):</b> System Analysis and Design</div>
                <div style="color: var(--text-secondary);"><b>DEBİM (LMS):</b> CENG311 Systems Analysis Studio</div>
            </div>
            <div style="display: flex; gap: 6px; margin-top: 8px;">
                <button class="studio-btn" style="padding: 4px 8px; font-size: 10px; font-weight: 700; color: #C084FC; background: rgba(168, 85, 247, 0.15);" onclick="alert('Portal adı (Resmi) tercih edildi.')">Portal'ı Koru</button>
                <button class="studio-btn" style="padding: 4px 8px; font-size: 10px; font-weight: 700; color: #60A5FA; background: rgba(59, 130, 246, 0.15);" onclick="alert('DEBİM adı tercih edildi.')">DEBİM'i Koru</button>
            </div>
        </div>

        <!-- Transcript Summary & Unverified GPA Card -->
        <div class="academic-card" style="margin-bottom: 10px;">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <span style="font-size: 10px; font-weight: 800; font-family: monospace; color: var(--text-tertiary);">TRANSKRİPT ÖZETİ</span>
                <span style="font-size: 9px; font-weight: 800; font-family: monospace; background: rgba(245, 158, 11, 0.15); color: #F59E0B; padding: 2px 6px; border-radius: 4px;">UNVERIFIED GPA MAPPING</span>
            </div>
            <div style="display: flex; justify-content: space-between; align-items: baseline; margin-top: 6px;">
                <div>
                    <span style="font-size: 14px; font-weight: 800;">42 Ders • 7 Dönem</span>
                    <div style="font-size: 11px; color: var(--text-secondary);">Geçilen: 39 | Kalınan: 3 (Tekrar)</div>
                </div>
                <div style="text-align: right;">
                    <div style="font-size: 18px; font-weight: 900; font-family: monospace; color: #F59E0B;">3.18</div>
                    <div style="font-size: 9px; color: var(--text-tertiary);">Portal Bildirilen GPA</div>
                </div>
            </div>
            <p style="font-size: 10px; color: var(--text-tertiary); margin-top: 6px; line-height: 1.3;">
                🛡️ Güvenlik Kuralı: Yakın Doğu Üniversitesi resmi katalog ağırlıkları teyit edilene kadar GPA hesaplaması korunur ve yapay zeka tarafından değiştirilmez.
            </p>
        </div>

        <!-- Reconciled Courses List -->
        <div class="academic-card">
            <span style="font-size: 10px; font-weight: 800; font-family: monospace; color: var(--text-tertiary);">EŞLEŞTİRİLMİŞ DERSLER (RECONCILED)</span>
            <div style="margin-top: 8px; display: flex; flex-direction: column; gap: 8px;">
                <div style="padding: 8px; background: var(--bg-card-secondary); border-radius: 8px;">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <span style="font-size: 12px; font-weight: 800; font-family: monospace;">CENG 311</span>
                        <div style="display: flex; gap: 4px;">
                            <span style="font-size: 8px; font-weight: 800; background: rgba(59, 130, 246, 0.2); color: #60A5FA; padding: 1px 4px; border-radius: 3px;">DEBİM</span>
                            <span style="font-size: 8px; font-weight: 800; background: rgba(168, 85, 247, 0.2); color: #C084FC; padding: 1px 4px; border-radius: 3px;">PORTAL</span>
                        </div>
                    </div>
                    <div style="font-size: 11px; color: var(--text-secondary); margin-top: 2px;">System Analysis and Design (3 Kredi / 5 AKTS)</div>
                </div>

                <div style="padding: 8px; background: var(--bg-card-secondary); border-radius: 8px;">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <span style="font-size: 12px; font-weight: 800; font-family: monospace;">ECC 206</span>
                        <div style="display: flex; gap: 4px;">
                            <span style="font-size: 8px; font-weight: 800; background: rgba(59, 130, 246, 0.2); color: #60A5FA; padding: 1px 4px; border-radius: 3px;">DEBİM</span>
                            <span style="font-size: 8px; font-weight: 800; background: rgba(168, 85, 247, 0.2); color: #C084FC; padding: 1px 4px; border-radius: 3px;">PORTAL</span>
                        </div>
                    </div>
                    <div style="font-size: 11px; color: var(--text-secondary); margin-top: 2px;">Signals and Systems (4 Kredi / 6 AKTS)</div>
                </div>

                <div style="padding: 8px; background: var(--bg-card-secondary); border-radius: 8px;">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <span style="font-size: 12px; font-weight: 800; font-family: monospace;">MATH 101</span>
                        <div style="display: flex; gap: 4px;">
                            <span style="font-size: 8px; font-weight: 800; background: rgba(168, 85, 247, 0.2); color: #C084FC; padding: 1px 4px; border-radius: 3px;">PORTAL</span>
                        </div>
                    </div>
                    <div style="font-size: 11px; color: var(--text-secondary); margin-top: 2px;">Calculus I (4 Kredi / 6 AKTS) • Not: BA</div>
                </div>
            </div>
        </div>
    `;
}

function simulateNEUSyncAll() {
    alert("🔄 Yakın Doğu Üniversitesi Canlı Senkronizasyonu:\n\n1. [DEBİM LMS]: 4 ders materyali ve 2 ödev teslim tarihi çekildi. (Moodle v2.6.0)\n2. [ÖĞRENCİ PORTALI]: 42 transkript dersi doğrulandı. (register.neu.edu.tr)\n3. [DELTA DETECTION]: CENG 311 için 1 yeni ödev ve 1 vize tarihi değişikliği tespit edildi.\n4. [PROVENANCE]: [DEBİM] ve [NEU STUDENT PORTAL] etiketleri iliştirildi.\n\nSonuç: DEBİM (2 değişiklik), Student Portal (1 değişiklik) başarıyla işlendi.");
}

function simulateDiagnosticsModal() {
    alert("🛠️ NEU Connector Diagnostics:\n\n[DEBİM LMS]\n• Google SAML Login Route: PASS\n• Moodle Dashboard (/my): PASS\n• Course Discovery: PASS\n• Materials: PASS\n• Assignments: PASS\n\n[STUDENT PORTAL OBS]\n• Direct HTTPS Login (/Login/Login): PASS\n• Navigation: PASS\n• Transcript Route: PASS\n• Grades: PASS\n• Exam Schedule: PASS\n\n[SELECTOR LEARNING REPORT]\n• Transcript Table: FOUND\n• Course Code Col: FOUND\n• Course Name Col: FOUND\n• Grade Col: FOUND\n• ECTS Col: FOUND\n\nSelector Profil Durumu: LIVE VERIFIED\nSıfır şifre / sıfır token garantisi onaylandı.");
}

function simulateMaterialImport() {
    alert("📥 DEBİM Ders Materyalleri Önizleme:\n\n1. [CENG 311] Chapter_01_Systems_Intro.pdf (2.4 MB)\n2. [CENG 311] UML_Sequence_Diagrams.pptx (5.1 MB)\n3. [ECC 206] Fourier_Transform_Tables.pdf (1.8 MB)\n4. [MATH 101] Calculus_Syllabus_2026.pdf (420 KB)\n\nİşlem: 'DOWNLOAD ALL' seçildiğinde authenticated WKDownload context kullanılarak dosyalar yerel SQLite/Dosya sistemine SHA-256 sağlama ile kaydedilir.");
}

function simulateTranscriptPreview() {
    alert("📄 NEU Transkript Önizlemesi (/StudentCourse/Transcript):\n\n• Toplam Ders: 42 (7 Dönem)\n• Geçilen: 39 (Geçti - Portal Onaylı)\n• Doğrulanmamış (Harf Notu): 3\n• Bildirilen CGPA: 3.18\n• Durum: PORTAL IMPORT — UNVERIFIED GPA MAPPING\n\nAlan Durumu:\n[Ders Kodu: VERIFIED] [Ders Adı: VERIFIED] [Harf Notu: VERIFIED] [Geçti/Kaldı: VERIFIED]");
}

// SCREEN 13: AI COMMAND CENTER
function renderAICommandCenter() {
    return `
        <div class="ios-nav-header">
            <div class="nav-title-group">
                <span class="nav-pretitle">BİLİŞSEL ASİSTANLAR</span>
                <h1 class="nav-main-title">AI Center</h1>
            </div>
            <span class="status-badge badge-indigo">6 AGENTS ACTIVE</span>
        </div>

        <!-- Agent 1: Academic Commander -->
        <div class="academic-card" style="border-left: 4px solid var(--academic-primary);">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <h3 style="font-size: 15px; font-weight: 800;">Academic Commander</h3>
                <span class="status-badge badge-emerald">READY</span>
            </div>
            <p style="font-size: 12px; color: var(--text-secondary); margin: 3px 0 6px;">
                Tüm derslerin takvimini, sınavlarını ve mezuniyet hedefini koordine eden baş stratejist.
            </p>
            <div style="font-size: 11px; font-family: monospace; color: var(--academic-primary);">
                Yetenek: Çapraz ders brifingi, kesin tarih denetimi, günlük eylem planı.
            </div>
        </div>

        <!-- Agent 2: Course Agent -->
        <div class="academic-card" style="border-left: 4px solid var(--academic-cyan);">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <h3 style="font-size: 15px; font-weight: 800;">Course Agent</h3>
                <span class="status-badge badge-emerald">READY</span>
            </div>
            <p style="font-size: 12px; color: var(--text-secondary); margin: 3px 0 6px;">
                Her ders için izole bellek tutan ve 'My Materials Only' kuralını uygulayan uzman.
            </p>
            <div style="font-size: 11px; font-family: monospace; color: var(--academic-cyan);">
                Yetenek: Ders transkripti temelli sorgulama, izolasyon garantisi.
            </div>
        </div>

        <!-- Agent 3: Notes Agent -->
        <div class="academic-card" style="border-left: 4px solid var(--academic-emerald);">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <h3 style="font-size: 15px; font-weight: 800;">Notes Agent</h3>
                <span class="status-badge badge-emerald">READY</span>
            </div>
            <p style="font-size: 12px; color: var(--text-secondary); margin: 3px 0 6px;">
                Full Lecture, Study Notes ve 5 dakikalık Nokta Atışı notlarını üreten mimar.
            </p>
            <div style="font-size: 11px; font-family: monospace; color: var(--academic-emerald);">
                Yetenek: Üç modlu not sentezi, versiyonlama koruması.
            </div>
        </div>

        <!-- Agent 4: Study Agent -->
        <div class="academic-card" style="border-left: 4px solid var(--academic-amber);">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <h3 style="font-size: 15px; font-weight: 800;">Study Agent</h3>
                <span class="status-badge badge-emerald">READY</span>
            </div>
            <p style="font-size: 12px; color: var(--text-secondary); margin: 3px 0 6px;">
                Aktif hatırlama ve spaced repetition çalışma bloklarını organize eden koç.
            </p>
            <div style="font-size: 11px; font-family: monospace; color: var(--academic-amber);">
                Yetenek: Pomodoro zaman blokları, zayıf konu hedefleme.
            </div>
        </div>

        <!-- Agent 5: Exam Agent -->
        <div class="academic-card" style="border-left: 4px solid var(--academic-crimson);">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <h3 style="font-size: 15px; font-weight: 800;">Exam Agent</h3>
                <span class="status-badge badge-emerald">READY</span>
            </div>
            <p style="font-size: 12px; color: var(--text-secondary); margin: 3px 0 6px;">
                Alıştırma sınavları ve simülasyonlar üreten taktik sınav analisti.
            </p>
            <div style="font-size: 11px; font-family: monospace; color: var(--academic-crimson);">
                Yetenek: 6 Soru türü, kesinlik iddia etmeyen dürüst etiketleme.
            </div>
        </div>

        <!-- Agent 6: University Portal Agent -->
        <div class="academic-card" style="border-left: 4px solid var(--academic-cyan);">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <h3 style="font-size: 15px; font-weight: 800;">University Portal Agent</h3>
                <span class="status-badge badge-emerald">READY</span>
            </div>
            <p style="font-size: 12px; color: var(--text-secondary); margin: 3px 0 6px;">
                Doğrulanmış SQLite/portal verilerinden duyuruları, sınav takvimini ve not dökümünü aktarır. Asla uydurma bilgi üretmez.
            </p>
            <div style="font-size: 11px; font-family: monospace; color: var(--academic-cyan);">
                Yetenek: Portal değişiklik özeti, acil duyuru brifingi, resmi not kontrolü.
            </div>
        </div>

        <!-- Local AI Telemetry Box -->
        <div class="academic-card">
            <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--text-tertiary);">TELEMETRİ & ÇALIŞMA SAYILARI</span>
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-top: 8px; font-size: 12px;">
                <div>Bulut Gemini: <b>${state.telemetry.geminiCalls}</b></div>
                <div>Apple Yerel AI: <b>${state.telemetry.appleLocalCalls}</b></div>
                <div>Kural Motoru: <b>${state.telemetry.ruleEngineCalls}</b></div>
                <div>Ortalama Hız: <b>${state.telemetry.avgLatencyMs} ms</b></div>
            </div>
        </div>
    `;
}

// SCREEN 14: PROFILE & SETTINGS
function renderProfileSettings() {
    return `
        <div class="ios-nav-header">
            <div class="nav-title-group">
                <span class="nav-pretitle">ÖĞRENCİ PROFİLİ</span>
                <h1 class="nav-main-title">Ayarlar</h1>
            </div>
        </div>

        <!-- Student Profile Card -->
        <div class="academic-card" style="display: flex; gap: 14px; align-items: center;">
            <div style="width: 52px; height: 52px; border-radius: 50%; background: var(--academic-primary); color: #FFF; display: flex; align-items: center; justify-content: center; font-size: 20px; font-weight: 800;">
                ET
            </div>
            <div>
                <h3 style="font-size: 16px; font-weight: 800;">Emre Türkmenoğlu</h3>
                <p style="font-size: 12px; color: var(--text-secondary);">Boğaziçi Üniversitesi • İletişim Fakültesi</p>
                <span style="font-size: 11px; color: var(--academic-cyan); font-weight: 700; font-family: monospace;">GPA: 3.42 • 4. Sınıf</span>
            </div>
        </div>

        <!-- AI Routing Mode Selector -->
        <div class="academic-card">
            <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--academic-primary);">AI ÇALIŞMA MODU</span>
            <div class="segmented-control" style="margin-top: 8px;">
                <div class="segment-item ${state.aiRoutingMode === 'automatic' ? 'active' : ''}" onclick="state.aiRoutingMode = 'automatic'; render();">Otomatik</div>
                <div class="segment-item ${state.aiRoutingMode === 'onlinePreferred' ? 'active' : ''}" onclick="state.aiRoutingMode = 'onlinePreferred'; render();">Bulut</div>
                <div class="segment-item ${state.aiRoutingMode === 'offlinePreferred' ? 'active' : ''}" onclick="state.aiRoutingMode = 'offlinePreferred'; render();">Yerel</div>
                <div class="segment-item ${state.aiRoutingMode === 'localOnly' ? 'active' : ''}" onclick="state.aiRoutingMode = 'localOnly'; render();">Yalnız Yerel</div>
            </div>
            <p style="font-size: 11px; color: var(--text-secondary); margin-top: 6px;">
                Varsayılan Model: <b>gemini-3.8-flash</b> (Developer API Free Tier — Sıfır Maliyet Garantisi).
            </p>
        </div>

        <!-- Security & Privacy -->
        <div class="academic-card">
            <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--text-tertiary);">GÜVENLİK & GİZLİLİK</span>
            <div style="margin-top: 10px; font-size: 13px; line-height: 2;">
                <div style="display: flex; justify-content: space-between;"><span>Face ID Koruması</span><span style="color: var(--academic-emerald); font-weight: 700;">AÇIK</span></div>
                <div style="display: flex; justify-content: space-between;"><span>Apple Keychain Şifreleme</span><span style="color: var(--academic-emerald); font-weight: 700;">AKTİF</span></div>
                <div style="display: flex; justify-content: space-between;"><span>Sıfır Dış Telemetri</span><span style="color: var(--academic-cyan); font-weight: 700;">GARANTİLİ</span></div>
            </div>
        </div>

        <!-- Storage Breakdown -->
        <div class="academic-card">
            <span style="font-size: 11px; font-weight: 800; font-family: monospace; color: var(--text-tertiary);">YEREL CİHAZ DEPOLAMASI</span>
            <div style="margin-top: 8px; font-size: 13px; line-height: 1.8;">
                <div style="display: flex; justify-content: space-between;"><span>Ders Ses Kayıtları (M4A)</span><span>1.2 GB</span></div>
                <div style="display: flex; justify-content: space-between;"><span>PDF Dokümanlar & Slaytlar</span><span>340 MB</span></div>
                <div style="display: flex; justify-content: space-between;"><span>Transkriptler & Notlar</span><span>24 MB</span></div>
                <div style="display: flex; justify-content: space-between;"><span>SQLite Veritabanı</span><span>12 MB</span></div>
            </div>
        </div>
    `;
}

// MODALS AND SHEETS
function renderModals() {
    const overlay = document.getElementById('sheet-overlay');
    if (!overlay) return;

    if (!state.activeSheet) {
        overlay.classList.remove('active');
        overlay.innerHTML = '';
        return;
    }

    overlay.classList.add('active');

    if (state.activeSheet === 'markers') {
        overlay.innerHTML = `
            <div class="ios-sheet-card">
                <div class="sheet-grabber"></div>
                <h3 style="font-size: 16px; font-weight: 800; margin-bottom: 4px;">Hoca Vurgusu Ekle</h3>
                <p style="font-size: 12px; color: var(--text-secondary); margin-bottom: 14px;">Ses kaydında tam bu saniyeye bir etiket koyun.</p>
                <div style="display: flex; flex-direction: column; gap: 8px;">
                    <button class="studio-btn" style="padding: 12px; border-left: 4px solid var(--academic-crimson);" onclick="addMarker('Sınav İpucu', 'examHint', 'crimson')">
                        🔴 Sınav Sorusu İpucu (Exam Hint)
                    </button>
                    <button class="studio-btn" style="padding: 12px; border-left: 4px solid var(--academic-amber);" onclick="addMarker('Önemli Vurgu', 'important', 'amber')">
                        🟠 Hoca Özellikle Vurguladı (Emphasis)
                    </button>
                    <button class="studio-btn" style="padding: 12px; border-left: 4px solid var(--academic-emerald);" onclick="addMarker('Kritik Tanım', 'definition', 'emerald')">
                        🟢 Önemli Tanım (Definition)
                    </button>
                    <button class="studio-btn" style="padding: 12px; border-left: 4px solid var(--academic-cyan);" onclick="addMarker('Soru / Merak', 'question', 'cyan')">
                        🔵 Soru / Kontrol Et (Question)
                    </button>
                    <button class="studio-btn" style="padding: 12px; border-left: 4px solid var(--academic-primary);" onclick="addMarker('Ödev Talimatı', 'assignment', 'indigo')">
                        🟣 Ödev / Proje Talimatı (Assignment)
                    </button>
                    <button class="studio-btn" style="padding: 12px;" onclick="closeSheet()">
                        İptal
                    </button>
                </div>
            </div>
        `;
    } else if (state.activeSheet === 'ai-status') {
        overlay.innerHTML = `
            <div class="ios-sheet-card">
                <div class="sheet-grabber"></div>
                <h3 style="font-size: 17px; font-weight: 800; margin-bottom: 4px;">Akıllı AI Router Durumu</h3>
                <p style="font-size: 13px; color: var(--text-secondary); line-height: 1.5; margin-bottom: 14px;">
                    AcademicOS; Apple cihaz içi yapay zekâ (Foundation Models), çevrimdışı yerel kural motoru ve Google Gemini Developer API (Free Tier) arasında akıllı köprü kurar.
                </p>
                <div class="academic-card">
                    <p style="font-size: 13px; line-height: 1.8;">
                        • <b>Sıfır Maliyet:</b> Developer API Free Tier sınırları aşılırsa otomatik yerel AI'a geçer.<br>
                        • <b>Sıfır Veri Sızıntısı:</b> Şifreler, LMS çerezleri ve Keychain asla buluta gitmez.<br>
                        • <b>Çevrimdışı Güvence:</b> İnternet kesilse bile tüm notlar ve dersler çalışır.
                    </p>
                </div>
                <button class="studio-btn" style="width: 100%; padding: 12px; justify-content: center; background: var(--academic-primary); color: #FFF; font-weight: 700;" onclick="closeSheet()">
                    Anladım
                </button>
            </div>
        `;
    } else if (state.activeSheet === 'edit-card' && state.selectedCardForEdit) {
        const c = state.selectedCardForEdit;
        overlay.innerHTML = `
            <div class="ios-sheet-card">
                <div class="sheet-grabber"></div>
                <h3 style="font-size: 16px; font-weight: 800; margin-bottom: 6px;">Flashcard Önerisini Düzenle</h3>
                <div style="margin-bottom: 10px;">
                    <label style="font-size: 11px; font-weight: 700; color: var(--text-tertiary);">Ön Yüz (Soru):</label>
                    <input type="text" id="edit-card-front" value="${c.front}" style="width: 100%; padding: 10px; background: var(--bg-card-secondary); border: 1px solid var(--border-subtle); border-radius: 8px; color: #FFF; font-size: 13px; margin-top: 4px;">
                </div>
                <div style="margin-bottom: 14px;">
                    <label style="font-size: 11px; font-weight: 700; color: var(--text-tertiary);">Arka Yüz (Cevap):</label>
                    <textarea id="edit-card-back" style="width: 100%; height: 70px; padding: 10px; background: var(--bg-card-secondary); border: 1px solid var(--border-subtle); border-radius: 8px; color: #FFF; font-size: 13px; margin-top: 4px;">${c.back}</textarea>
                </div>
                <div style="display: flex; gap: 8px;">
                    <button class="studio-btn" style="flex: 1; justify-content: center; background: var(--academic-primary); color: #FFF;" onclick="saveEditedCard(${c.id})">
                        Kaydet & Onayla
                    </button>
                    <button class="studio-btn" style="flex: 1; justify-content: center;" onclick="closeSheet()">
                        İptal
                    </button>
                </div>
            </div>
        `;
    }
}

function openAudioMarkersSheet() {
    state.activeSheet = 'markers';
    render();
}

function openAIStatusSheet() {
    state.activeSheet = 'ai-status';
    render();
}

function closeSheet() {
    state.activeSheet = null;
    render();
}

function addMarker(title, type, badgeStyle) {
    const time = formatTimer(state.recordingTimerSeconds);
    state.audioMarkers.unshift({ time, title, type, badgeStyle });
    closeSheet();
}

function saveEditedCard(id) {
    const front = document.getElementById('edit-card-front')?.value;
    const back = document.getElementById('edit-card-back')?.value;
    if (front && back) {
        state.suggestedCards = state.suggestedCards.filter(s => s.id !== id);
        state.flashcardsDeck.unshift({
            id: Date.now(),
            front: front,
            back: back,
            type: "edited",
            flipped: false
        });
    }
    closeSheet();
}

function openRecordingStudio() {
    state.currentScreen = 'recording';
    render();
}

function openTranscriptScreen() {
    state.currentScreen = 'transcript';
    render();
}

function openLectureIntelligenceResult() {
    state.currentScreen = 'intelligence';
    render();
}

function openQuizScreen(count = 5) {
    state.currentScreen = 'quiz';
    state.activeQuizQuestion = 0;
    state.quizScore = 0;
    state.quizAnswered = {};
    state.quizFinished = false;
    render();
}

function openUniversityPortal() {
    state.currentScreen = 'university';
    render();
}

function openAddCourseSheet() {
    alert("Yeni Ders Ekleme: Kod, Ad, Bölüm ve Kredi bilgisi girerek yeni ders açabilirsiniz.");
}

// Window Onload Trigger
window.addEventListener('DOMContentLoaded', () => {
    initApp();
});
