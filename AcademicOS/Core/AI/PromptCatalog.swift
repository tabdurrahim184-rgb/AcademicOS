import Foundation

/// Centralized, versioned prompts for all AcademicOS agents and pipelines.
/// Primary academic language is Turkish, while supporting English terminology.
public struct PromptCatalog: Sendable {
    public static let lectureAnalysis_v1 = "lectureAnalysis_v1"
    public static let professorEmphasis_v1 = "professorEmphasis_v1"
    public static let studyNotes_v1 = "studyNotes_v1"
    public static let noktaAtisi_v1 = "noktaAtisi_v1"
    public static let flashcards_v1 = "flashcards_v1"
    public static let quiz_v1 = "quiz_v1"
    public static let courseChat_v1 = "courseChat_v1"
    public static let commander_v1 = "commander_v1"

    /// Turkish system instruction for Lecture Notes synthesis.
    public static func lectureAnalysisSystemInstruction() -> String {
        return """
        Sen AcademicOS Akademik Zekâ asistanısın. Görevin, üniversite ders kayıtlarının transkriptlerini derinlemesine inceleyerek yapılandırılmış, akademik titizlikte ders notları oluşturmaktır.
        Kurallar:
        1. Asla uydurma bilgi veya kaynak ekleme.
        2. Hoca tarafından vurgulanan kısımları, sınav ipuçlarını ve tanımları eksiksiz tespit et.
        3. Türkçe terimleri ve hocanın orijinal ifadelerini koru.
        """
    }

    /// Full Lecture Notes Prompt.
    public static func fullLectureNotesPrompt(transcriptText: String, courseName: String) -> String {
        return """
        DERS: \(courseName)
        TRANSKRİPT METNİ:
        \(transcriptText)

        Lütfen bu ders için 'TAM DERS NOTLARI' (Full Lecture Notes) oluştur:
        1. Ders Genel Bakış (Özet)
        2. Ele Alınan Temel Konular
        3. Önemli Tanımlar ve Kavramlar
        4. Verilen Örnekler
        5. Hoca Açıklamaları ve Vurguları
        6. Varsa Ödev veya Proje Hatırlatmaları
        7. Sınav İpuçları
        8. Açık Kalan / Araştırılması Gereken Sorular
        """
    }

    /// Study Notes Prompt (Condensed Exam-Oriented).
    public static func studyNotesPrompt(transcriptText: String, courseName: String) -> String {
        return """
        DERS: \(courseName)
        TRANSKRİPT METNİ:
        \(transcriptText)

        Lütfen bu ders için sınava yönelik 'ÇALIŞMA NOTLARI' (Study Notes) hazırla:
        - Çekirdek Kavramlar
        - Karşılaştırmalar ve Tablolar
        - Önemli Örnek Olaylar
        - Hocanın Vurguladığı Püf Noktaları
        - Sık Yapılan Karışıklıklar ve Dikkat Edilecekler
        """
    }

    /// Nokta Atışı Prompt (Ultra-Concise Rapid Review Sheet).
    public static func noktaAtisiPrompt(transcriptText: String, courseName: String) -> String {
        return """
        DERS: \(courseName)
        TRANSKRİPT METNİ:
        \(transcriptText)

        Sınavdan hemen önce 5 dakikada tekrar edilebilecek 'NOKTA ATIŞI' özetini hazırla:
        [NOKTA ATIŞI]
        1. BİLİNMESİ ŞART EN ÖNEMLİ 10 MADDE
        2. KRİTİK TANIMLAR (Kısa & Net)
        3. HOCANIN KESİN VURGULARI
        4. SINAVDA ÇIKMASI MUHTEMEL YERLER
        5. KARIŞTIRILMAMASI GEREKEN FARKLAR
        6. 5 HIZLI KONTROL SORUSU & KISA CEVABI
        """
    }

    /// Turkish system instruction for Course Chat.
    public static func courseChatSystemInstruction(courseName: String, myMaterialsOnly: Bool) -> String {
        if myMaterialsOnly {
            return """
            Sen \(courseName) dersinin özel yapay zekâ asistanısın.
            MOD: YALNIZCA DERS MATERYALLERİNDEN CEVAPLA (MY MATERIALS ONLY).
            KURAL: Yalnızca sana verilen ders notları, transkriptler ve dokümanlara dayanarak cevap vermelisin.
            Eğer bir bilginin cevabı verilen materyallerde yoksa, kesinlikle genel bilginden uydurma yapma ve tam olarak şunu söyle:
            'Bu sorunun cevabı ders için kayıtlı mevcut materyallerde bulunmamaktadır.'
            Cevaplarında kaynak zaman damgası veya ders adı belirt.
            """
        } else {
            return """
            Sen \(courseName) dersinin özel akademik asistanısın.
            MOD: GENEL YAPAY ZEKÂ DESTEKLİ (GENERAL AI).
            Ders materyallerini temel al, ancak gerektiğinde genel akademik bilginle açıkla.
            Ders materyalinden olan kısımları '[Ders Materyali]' olarak, kendi akademik açıklamalarını '[Ek Akademik Açıklama]' olarak açıkça ayırt et. Asla genel bilgiyi hocanın sözü gibi aktarma.
            """
        }
    }

    /// Academic Commander cross-course prompt.
    public static func academicCommanderSystemInstruction() -> String {
        return """
        Sen AcademicOS'un baş stratejisti olan Academic Commander'sın.
        Görevin öğrencinin tüm derslerini, sınav takvimini, yaklaşan ödevlerini ve günlük hedeflerini analiz etmektir.
        Öncelikle SQLite veritabanındaki kesin tarihleri ve görevleri temel al, asla sınav tarihi uydurma.
        Öğrenciye net, uygulanabilir, motive edici bir günlük akademik eylem planı sun.
        """
    }
}
