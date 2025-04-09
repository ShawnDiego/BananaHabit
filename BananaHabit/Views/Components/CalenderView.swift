//import SwiftUI
//
//struct ContentView2: View {
//    @State private var showCalendar = false
//    @State private var currentMonth = Date()
//    @State private var selectedDate = Date()
//
//    var body: some View {
//        ZStack {
//            // Main content view
//            VStack {
//                Button(action: {
//                    withAnimation {
//                        showCalendar.toggle()
//                    }
//                }) {
//                    Text("Show Calendar")
//                        .padding()
//                        .foregroundColor(.white)
//                        .background(Color.blue)
//                        .cornerRadius(8)
//                }
//                Spacer()
//            }
//            
//            // Calendar Overlay
//            if showCalendar {
//                VStack {
//                    Spacer()
//                    
//                    VStack(spacing: 0) {
//                        HStack {
//                            Text((currentMonth), style: .date)
//                                .font(.headline)
//                                .foregroundColor(.white)
//                                .padding()
//                            
//                            Spacer()
//                            
//                            // Close button
//                            Button(action: {
//                                withAnimation {
//                                    showCalendar.toggle()
//                                }
//                            }) {
//                                Image(systemName: "chevron.down")
//                                    .foregroundColor(.white)
//                                    .padding()
//                            }
//                        }
//                        
//                        // Calendar Grid
//                        BottomCalendarView(currentMonth: $currentMonth, selectedDate: $selectedDate)
//                            .frame(maxHeight: 400)
//                        
//                        Spacer()
//                    }
//                    .background(BlurView(style: .systemMaterialDark))
//                    .cornerRadius(20)
//                    .padding()
//                    .shadow(radius: 20)
//                }
//                .edgesIgnoringSafeArea(.all)
//                .background(Color.black.opacity(0.6).onTapGesture {
//                    withAnimation {
//                        showCalendar.toggle()
//                    }
//                })
//            }
//        }
//        .background(Color.black)
//    }
//    
//    // Helper function to format the date correctly as "2025年4月"
//    private func formatDate(_ date: Date) -> String {
//        let dateFormatter = DateFormatter()
//        dateFormatter.locale = Locale(identifier: "zh_CN")
//        dateFormatter.dateFormat = "yyyy年MM月"
//        return dateFormatter.string(from: date)
//    }
//}
//
//struct BottomCalendarView: View {
//    @Binding var currentMonth: Date
//    @Binding var selectedDate: Date
//    
//    let calendar = Calendar.current
//    let dateFormatter = DateFormatter()
//    
//    init(currentMonth: Binding<Date>, selectedDate: Binding<Date>) {
//        self._currentMonth = currentMonth
//        self._selectedDate = selectedDate
//        dateFormatter.dateFormat = "d"
//    }
//    
//    var body: some View {
//        VStack {
//            HStack {
//                Button(action: {
//                    currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? Date()
//                }) {
//                    Image(systemName: "chevron.left")
//                        .foregroundColor(.white)
//                        .padding()
//                }
//                
//                Spacer()
//                
//                Button(action: {
//                    currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? Date()
//                }) {
//                    Image(systemName: "chevron.right")
//                        .foregroundColor(.white)
//                        .padding()
//                }
//            }
//            .padding()
//            
//            let daysInMonth = getDaysInMonth(for: currentMonth)
//            let firstDayOfMonth = calendar.dateComponents([.weekday], from: currentMonth).weekday ?? 1
//            let rows = createCalendarRows(daysInMonth: daysInMonth, firstDayOfMonth: firstDayOfMonth)
//            
//            ForEach(rows, id: \.self) { row in
//                HStack {
//                    ForEach(row, id: \.self) { day in
//                        Text(day)
//                            .frame(maxWidth: .infinity, maxHeight: .infinity)
//                            .padding()
//                            .background(self.getDayBackgroundColor(for: day))
//                            .foregroundColor(self.getDayTextColor(for: day))
//                            .cornerRadius(10)
//                            .onTapGesture {
//                                if let dayInt = Int(day), let selected = calendar.date(bySetting: .day, value: dayInt, of: currentMonth) {
//                                    selectedDate = selected
//                                }
//                            }
//                    }
//                }
//            }
//        }
//        .background(Color.white)
//        .cornerRadius(15)
//        .padding(.horizontal)
//    }
//    
//    func getDaysInMonth(for date: Date) -> [Int] {
//        guard let range = calendar.range(of: .day, in: .month, for: date) else {
//            return []
//        }
//        return Array(range.lowerBound..<range.upperBound)
//    }
//    
//    func createCalendarRows(daysInMonth: [Int], firstDayOfMonth: Int) -> [[String]] {
//        var rows: [[String]] = []
//        var currentRow: [String] = Array(repeating: "", count: firstDayOfMonth - 1)
//        
//        for day in daysInMonth {
//            currentRow.append("\(day)")
//            if currentRow.count == 7 {
//                rows.append(currentRow)
//                currentRow = []
//            }
//        }
//        
//        if !currentRow.isEmpty {
//            rows.append(currentRow)
//        }
//        
//        return rows
//    }
//    
//    func getDayBackgroundColor(for day: String) -> Color {
//        // Example condition for moon phases (could be customized)
//        if Int(day)! % 3 == 0 {
//            return Color.gray // For certain days, show a different moon phase background
//        } else if Int(day)! % 2 == 0 {
//            return Color.blue.opacity(0.5)
//        }
//        return Color.clear
//    }
//    
//    func getDayTextColor(for day: String) -> Color {
//        return (Int(day)! % 2 == 0) ? .white : .black
//    }
//}
//
//struct BlurView: UIViewRepresentable {
//    var style: UIBlurEffect.Style
//    
//    func makeUIView(context: Context) -> UIVisualEffectView {
//        let effect = UIBlurEffect(style: style)
//        let view = UIVisualEffectView(effect: effect)
//        return view
//    }
//    
//    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
//}
//
//// Preview code
//struct ContentView2_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView2()
//    }
//}
