import SwiftUI
import Combine

// MARK: - TRỪU TƯỢNG
// Quy định những thông tin mà một loại sách phải cung cấp.

protocol BookInformation {
    var kind: String { get }
    func information() -> String
}

// MARK: - LỚP CHA: SÁCH
// ĐÓNG GÓI: dữ liệu private, bên ngoài chỉ được đọc.

class Book: Identifiable, BookInformation {
    let id: UUID

    private let storedTitle: String
    private let storedAuthor: String

    var title: String { storedTitle }
    var author: String { storedAuthor }

    var kind: String {
        "Sách"
    }

    init(
        id: UUID = UUID(),
        title: String,
        author: String
    ) {
        self.id = id
        self.storedTitle = title
        self.storedAuthor = author
    }

    func information() -> String {
        """
        Tên sách: \(title)
        Tác giả: \(author)
        """
    }
}

// MARK: - KẾ THỪA: SÁCH GIẤY

final class PrintedBook: Book {
    private let pageCount: Int

    override var kind: String {
        "Sách giấy"
    }

    init(
        title: String,
        author: String,
        pageCount: Int
    ) {
        self.pageCount = pageCount
        super.init(title: title, author: author)
    }

    // ĐA HÌNH: ghi đè cách cung cấp thông tin.
    override func information() -> String {
        """
        \(super.information())
        Loại: \(kind)
        Số trang: \(pageCount)
        """
    }
}

// MARK: - KẾ THỪA: SÁCH ĐIỆN TỬ

final class EBook: Book {
    private let fileFormat: String
    private let fileSizeMB: Double

    override var kind: String {
        "Sách điện tử"
    }

    init(
        title: String,
        author: String,
        fileFormat: String,
        fileSizeMB: Double
    ) {
        self.fileFormat = fileFormat
        self.fileSizeMB = fileSizeMB
        super.init(title: title, author: author)
    }

    // ĐA HÌNH: cùng phương thức nhưng nội dung khác.
    override func information() -> String {
        """
        \(super.information())
        Loại: \(kind)
        Định dạng: \(fileFormat)
        Dung lượng: \(fileSizeMB) MB
        """
    }
}

// MARK: - SINH VIÊN

final class Student: Identifiable {
    let id: UUID
    private let storedName: String

    var name: String { storedName }

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.storedName = name
    }
}

// MARK: - PHIẾU MƯỢN

final class BorrowRecord: Identifiable {
    let id = UUID()

    private let storedBookID: UUID
    private let storedStudentID: UUID
    private let storedBorrowedAt: Date

    var bookID: UUID { storedBookID }
    var studentID: UUID { storedStudentID }
    var borrowedAt: Date { storedBorrowedAt }

    init(bookID: UUID, studentID: UUID) {
        self.storedBookID = bookID
        self.storedStudentID = studentID
        self.storedBorrowedAt = Date()
    }
}

// MARK: - MÀU SẮC

enum LibraryTheme {
    static let blue = Color(
        red: 0.08,
        green: 0.34,
        blue: 0.68
    )

    static let red = Color(
        red: 0.70,
        green: 0.08,
        blue: 0.22
    )
}

// MARK: - QUẢN LÝ DỮ LIỆU VÀ XỬ LÝ

@MainActor
final class LibraryViewModel: ObservableObject {
 
    @Published private(set) var books: [Book]
    @Published private(set) var students: [Student]
    @Published private(set) var records: [BorrowRecord] = []

    @Published private(set) var currentStudentID: UUID
    @Published private(set) var selectedBookIDs: Set<UUID> = []

    @Published var showingMessage = false
    @Published private(set) var message = ""

    init() {
        let initialStudents = [
            Student(name: "Nguyen Van A"),
            Student(name: "Tran Thi B"),
            Student(name: "Le Van C")
        ]

        students = initialStudents
        currentStudentID = initialStudents[0].id

        
        books = [
            PrintedBook(
                title: "Sách 01",
                author: "Tác giả A",
                pageCount: 200
            ),
            EBook(
                title: "Sách 02",
                author: "Tác giả B",
                fileFormat: "PDF",
                fileSizeMB: 5.2
            )
        ]
    }

    var currentStudent: Student? {
        students.first { $0.id == currentStudentID }
    }

    func record(for book: Book) -> BorrowRecord? {
        records.first { $0.bookID == book.id }
    }

    func borrower(of book: Book) -> Student? {
        guard let record = record(for: book) else {
            return nil
        }

        return students.first {
            $0.id == record.studentID
        }
    }

    func borrowedBooks(by student: Student) -> [Book] {
        let bookIDs = Set(
            records
                .filter { $0.studentID == student.id }
                .map { $0.bookID }
        )

        return books.filter {
            bookIDs.contains($0.id)
        }
    }

    func changeStudent(to student: Student) {
        currentStudentID = student.id
        selectedBookIDs.removeAll()
    }

    func isChecked(_ book: Book) -> Bool {
        selectedBookIDs.contains(book.id)
            || borrower(of: book)?.id == currentStudentID
    }

    func toggle(_ book: Book) {
        guard record(for: book) == nil else { return }

        if selectedBookIDs.contains(book.id) {
            selectedBookIDs.remove(book.id)
        } else {
            selectedBookIDs.insert(book.id)
        }
    }

    func borrowSelectedBooks() {
        guard let student = currentStudent else {
            notify("Vui lòng chọn sinh viên.")
            return
        }

        let availableBooks = books.filter {
            selectedBookIDs.contains($0.id)
                && record(for: $0) == nil
        }

        guard !availableBooks.isEmpty else {
            notify("Vui lòng chọn ít nhất một sách chưa được mượn.")
            return
        }

        let newRecords = availableBooks.map {
            BorrowRecord(
                bookID: $0.id,
                studentID: student.id
            )
        }

        records.append(contentsOf: newRecords)
        selectedBookIDs.removeAll()

        notify(
            "\(student.name) đã mượn \(newRecords.count) sách."
        )
    }

    func returnBook(_ book: Book) {
        guard record(for: book) != nil else {
            notify("Sách này chưa được mượn.")
            return
        }

        records.removeAll { $0.bookID == book.id }
        selectedBookIDs.remove(book.id)

        notify("Đã trả \(book.title).")
    }

    // Chỉ nhận đối tượng sách hợp lệ vào danh sách.
    func addBook(_ book: Book) {
        books.append(book)
    }

    func addStudent(name: String) {
        let cleanedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !cleanedName.isEmpty else {
            notify("Vui lòng nhập tên sinh viên.")
            return
        }

        students.append(Student(name: cleanedName))
    }

    private func notify(_ text: String) {
        message = text
        showingMessage = true
    }
}

// MARK: - MÀN HÌNH GỐC: BA TAB

struct ContentView: View {
    @StateObject private var viewModel = LibraryViewModel()

    var body: some View {
        TabView {
            ManagementView(viewModel: viewModel)
                .tabItem {
                    Label(
                        "Quản lý",
                        systemImage: "house.fill"
                    )
                }

            BookListView(viewModel: viewModel)
                .tabItem {
                    Label(
                        "DS Sách",
                        systemImage: "books.vertical.fill"
                    )
                }

            StudentListView(viewModel: viewModel)
                .tabItem {
                    Label(
                        "Sinh viên",
                        systemImage: "person.fill"
                    )
                }
        }
        .tint(LibraryTheme.blue)
        .preferredColorScheme(.light)
        .alert(
            "Thông báo",
            isPresented: $viewModel.showingMessage
        ) {
            Button("Đóng", role: .cancel) {}
        } message: {
            Text(viewModel.message)
        }
    }
}

// MARK: - TAB QUẢN LÝ

struct ManagementView: View {
    @ObservedObject var viewModel: LibraryViewModel

    @State private var showingStudentPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Hệ thống\nQuản lý Thư viện")
                    .font(.system(size: 25, weight: .bold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                    .padding(.bottom, 64)

                Text("Sinh viên")
                    .font(.title3.bold())
                    .padding(.bottom, 12)

                HStack(spacing: 14) {
                    Text(viewModel.currentStudent?.name ?? "")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    Color.gray.opacity(0.6),
                                    lineWidth: 1
                                )
                        }

                    Button {
                        showingStudentPicker = true
                    } label: {
                        Text("Thay đổi")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 50)
                            .background(LibraryTheme.blue)
                            .clipShape(
                                RoundedRectangle(cornerRadius: 10)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Text("Danh sách sách")
                    .font(.title3.bold())
                    .padding(.top, 26)
                    .padding(.bottom, 16)

                VStack(spacing: 10) {
                    ForEach(viewModel.books) { book in
                        bookRow(book)
                    }
                }
                .padding(16)
                .frame(
                    maxWidth: .infinity,
                    minHeight: 220,
                    alignment: .top
                )
                .background(Color.gray.opacity(0.28))
                .clipShape(
                    RoundedRectangle(cornerRadius: 12)
                )

                Button {
                    viewModel.borrowSelectedBooks()
                } label: {
                    Text("Thêm")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 190, height: 52)
                        .background(LibraryTheme.blue)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 10)
                        )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
        }
        .background(Color.white)
        .sheet(isPresented: $showingStudentPicker) {
            NavigationStack {
                List(viewModel.students) { student in
                    Button {
                        viewModel.changeStudent(to: student)
                        showingStudentPicker = false
                    } label: {
                        HStack {
                            Text(student.name)
                                .foregroundStyle(.primary)

                            Spacer()

                            if student.id == viewModel.currentStudentID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(LibraryTheme.blue)
                            }
                        }
                    }
                }
                .navigationTitle("Chọn sinh viên")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Đóng") {
                            showingStudentPicker = false
                        }
                    }
                }
            }
        }
    }

    private func bookRow(_ book: Book) -> some View {
        let borrower = viewModel.borrower(of: book)

        let borrowedByOther = borrower != nil
            && borrower?.id != viewModel.currentStudentID

        return Button {
            viewModel.toggle(book)
        } label: {
            HStack(spacing: 14) {
                Image(
                    systemName: viewModel.isChecked(book)
                        ? "checkmark.square.fill"
                        : "square"
                )
                .font(.system(size: 23))
                .foregroundStyle(
                    viewModel.isChecked(book)
                        ? LibraryTheme.red
                        : Color.gray
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(book.title)
                        .font(.system(size: 17))
                        .foregroundStyle(.black.opacity(0.7))

                    if let borrower {
                        Text("Đang mượn: \(borrower.name)")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(minHeight: 54)
            .background(Color.white)
            .clipShape(
                RoundedRectangle(cornerRadius: 23)
            )
            .shadow(
                color: .black.opacity(0.12),
                radius: 5,
                y: 4
            )
            .opacity(borrowedByOther ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(borrower != nil)
    }
}

// MARK: - TAB DANH SÁCH SÁCH

struct BookListView: View {
    @ObservedObject var viewModel: LibraryViewModel

    @State private var showingAddBook = false

    var body: some View {
        NavigationStack {
            List(viewModel.books) { book in
                NavigationLink {
                    BookDetailView(
                        book: book,
                        viewModel: viewModel
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(book.title)
                            .font(.headline)

                        Text("\(book.author) • \(book.kind)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(
                            viewModel.record(for: book) == nil
                                ? "Có thể mượn"
                                : "Đang được mượn"
                        )
                        .font(.caption)
                        .foregroundStyle(
                            viewModel.record(for: book) == nil
                                ? Color.green
                                : Color.orange
                        )
                    }
                    .padding(.vertical, 5)
                }
            }
            .navigationTitle("Danh sách sách")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddBook = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBook) {
                AddBookView(viewModel: viewModel)
            }
        }
    }
}

// MARK: - FORM THÊM SÁCH

struct AddBookView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: LibraryViewModel

    @State private var title = ""
    @State private var author = ""
    @State private var isEBook = false

    @State private var pageCount = ""
    @State private var fileFormat = "PDF"
    @State private var fileSize = ""

    private var cleanedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanedAuthor: String {
        author.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cleanedFormat: String {
        fileFormat.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedFileSize: Double? {
        Double(fileSize.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        guard !cleanedTitle.isEmpty,
              !cleanedAuthor.isEmpty else {
            return false
        }

        if isEBook {
            guard let size = parsedFileSize else {
                return false
            }

            return !cleanedFormat.isEmpty
                && size.isFinite
                && size > 0
        } else {
            return (Int(pageCount) ?? 0) > 0
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Thông tin chung") {
                    TextField("Tên sách", text: $title)
                    TextField("Tác giả", text: $author)

                    Picker("Loại sách", selection: $isEBook) {
                        Text("Sách giấy").tag(false)
                        Text("Sách điện tử").tag(true)
                    }
                }

                Section("Thông tin bổ sung") {
                    if isEBook {
                        TextField(
                            "Định dạng: PDF, EPUB...",
                            text: $fileFormat
                        )
                        .textInputAutocapitalization(.characters)

                        TextField(
                            "Dung lượng (MB)",
                            text: $fileSize
                        )
                        .keyboardType(.decimalPad)
                    } else {
                        TextField("Số trang", text: $pageCount)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("Thêm sách")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard canSave else { return }

        let newBook: Book

        if isEBook {
            guard let size = parsedFileSize else { return }

            newBook = EBook(
                title: cleanedTitle,
                author: cleanedAuthor,
                fileFormat: cleanedFormat.uppercased(),
                fileSizeMB: size
            )
        } else {
            guard let pages = Int(pageCount) else { return }

            newBook = PrintedBook(
                title: cleanedTitle,
                author: cleanedAuthor,
                pageCount: pages
            )
        }

        viewModel.addBook(newBook)
        dismiss()
    }
}

// MARK: - CHI TIẾT SÁCH

struct BookDetailView: View {
    let book: Book

    @ObservedObject var viewModel: LibraryViewModel

    // Làm việc qua giao thức để tách giao diện khỏi loại sách cụ thể.
    private var bookInformation: any BookInformation {
        book
    }

    var body: some View {
        Form {
            Section("Thông tin sách") {
                // ĐA HÌNH:
                // Tự gọi phiên bản của PrintedBook hoặc EBook.
                Text(bookInformation.information())
                    .lineSpacing(6)
                    .padding(.vertical, 6)
            }

            Section("Thông tin mượn") {
                if let borrower = viewModel.borrower(of: book) {
                    LabeledContent(
                        "Sinh viên",
                        value: borrower.name
                    )

                    if let record = viewModel.record(for: book) {
                        LabeledContent("Ngày mượn") {
                            Text(
                                record.borrowedAt,
                                format: .dateTime
                                    .day()
                                    .month()
                                    .year()
                            )
                        }
                    }

                    Button("Trả sách", role: .destructive) {
                        viewModel.returnBook(book)
                    }
                } else {
                    Text("Sách chưa được mượn.")
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("Chi tiết sách")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - TAB SINH VIÊN

struct StudentListView: View {
    @ObservedObject var viewModel: LibraryViewModel

    @State private var showingAddStudent = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List(viewModel.students) { student in
                NavigationLink {
                    StudentDetailView(
                        student: student,
                        viewModel: viewModel
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(student.name)
                            .font(.headline)

                        Text(
                            "Đang mượn: "
                            + "\(viewModel.borrowedBooks(by: student).count)"
                            + " sách"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 5)
                }
            }
            .navigationTitle("Sinh viên")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newName = ""
                        showingAddStudent = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert(
                "Thêm sinh viên",
                isPresented: $showingAddStudent
            ) {
                TextField("Họ tên sinh viên", text: $newName)

                Button("Hủy", role: .cancel) {}

                Button("Thêm") {
                    viewModel.addStudent(name: newName)
                }
                .disabled(
                    newName.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                )
            }
        }
    }
}

// MARK: - CHI TIẾT SINH VIÊN

struct StudentDetailView: View {
    let student: Student

    @ObservedObject var viewModel: LibraryViewModel

    private var borrowedBooks: [Book] {
        viewModel.borrowedBooks(by: student)
    }

    var body: some View {
        List {
            Section("Sinh viên") {
                Text(student.name)
                    .font(.headline)
            }

            Section("Sách đang mượn") {
                if borrowedBooks.isEmpty {
                    Text("Sinh viên chưa mượn sách.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(borrowedBooks) { book in
                        NavigationLink {
                            BookDetailView(
                                book: book,
                                viewModel: viewModel
                            )
                        } label: {
                            VStack(
                                alignment: .leading,
                                spacing: 4
                            ) {
                                Text(book.title)

                                Text(book.kind)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Thông tin sinh viên")
        .navigationBarTitleDisplayMode(.inline)
    }
}
