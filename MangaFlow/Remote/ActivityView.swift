import SwiftUI

struct ActivityView:View {
    @Bindable var remote:RemoteModel
    let library:LibraryModel
    @Environment(\.palette) private var p
    private var jobs:[RemoteJob] {remote.jobs.filter {$0.kind == "download" && !remote.hiddenJobs.contains($0.id)}}
    private var groups:[(String,[RemoteJob])] {[
        ("Sur le Mac",jobs.filter {$0.state == "running"}),
        ("Vers cet appareil",jobs.filter {$0.id == remote.transferJobID}),
        ("En attente",jobs.filter {$0.state == "queued"}),
        ("À revoir",jobs.filter {$0.state == "failed" || $0.state == "cancelled"}),
        ("Terminées",jobs.filter {$0.state == "completed" && $0.id != remote.transferJobID})]}
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:20) {
                    ThemeHeader(title:p.theme == .brutal ? "Activité / file" : "Activité",remote:remote,library:library)
                    Text(p.theme == .brutal ? String(format:"%02d.",jobs.filter {!$0.finished}.count) : "\(jobs.filter {!$0.finished}.count) chapitre(s)\nen route.").font(p.font(p.theme == .brutal ? 80 : 40,title:true))
                    if !remote.connected {Text("Mac injoignable · son dernier état est affiché. La lecture locale reste disponible.").font(p.font(12))}
                    if library.isBusy && !remote.importing {
                        VStack(alignment:.leading,spacing:10) {Text("Découpage sur cet appareil").font(p.font(20,title:true));Text(library.status);ProgressView(value:Double(library.activeDocument?.processedCount ?? 0),total:Double(max(1,library.activeDocument?.pages.count ?? 1)));Button("Pause") {library.cancel()}}.themeCard()
                    }
                    if let interrupted=UserDefaults.standard.string(forKey:"interruptedTransfer"),!remote.importing,jobs.contains(where:{$0.id == interrupted}) {Text("Un transfert a été interrompu. Relance son import depuis le chapitre terminé sur le Mac.").themeCard()}
                    ForEach(groups,id:\.0) {title,items in
                        if !items.isEmpty {
                            HStack {Text(p.theme == .holo ? title : title.uppercased()).font(p.font(20,title:true));Spacer();if title == "Terminées" {Button("Effacer") {remote.clearFinishedHistory()}.font(p.font(12))}}
                            ForEach(items) {job in row(job)}
                        }
                    }
                    if jobs.isEmpty && !library.isBusy {Text("Aucune activité. Télécharge un chapitre depuis Explorer.").themeCard()}
                }.padding(p.theme == .brutal ? 14 : 18).padding(.bottom,24).frame(maxWidth:850).frame(maxWidth:.infinity)
            }.background {ThemeBackground()}.toolbar(.hidden,for:.navigationBar).refreshable {await remote.refresh()}
        }
    }
    private func row(_ job:RemoteJob)->some View {
        VStack(alignment:.leading,spacing:12) {
            Text((job.target.manga?.title ?? "Manga")+" · "+(job.target.chapter?.title ?? "Chapitre")).font(p.font(20,title:true))
            if remote.transferJobID == job.id {
                Text(remote.transferPhase)
                ProgressView(value:remote.transferPhase == "Découpage sur cet appareil" ? Double(library.activeDocument?.processedCount ?? 0)/Double(max(1,library.activeDocument?.pages.count ?? 1)) : remote.transferProgress)
                Button("Annuler") {remote.cancelTransfer(library:library)}
            } else if job.state == "running" {
                ProgressView(value:Double(job.progress.completed),total:Double(max(1,job.progress.total)))
                Text("\(job.progress.completed) / \(job.progress.total) images"+estimate(job)).font(p.font(12))
                Button("Annuler",role:.destructive) {Task {await remote.cancel(job)}}
            } else if job.state == "queued" {
                Text((job.queuePosition.map { "Position \($0) · " } ?? "En attente · ") + job.target.sourceID).font(p.font(12))
                Button("Annuler",role:.destructive) {Task {await remote.cancel(job)}}
            } else if job.state == "completed" {
                let imported=library.documents.contains {$0.remoteArtifactID == (remote.connection?.serverID ?? "")+":"+(job.artifactID ?? "")}
                Text(imported ? "Prêt à lire hors ligne" : "CBZ prêt sur le Mac").font(p.font(12))
                Button(imported ? "Lire" : "Importer et lire") {remote.startImport(job,library:library)}.buttonStyle(ThemeButtonStyle()).disabled(remote.importing || library.isBusy).accessibilityIdentifier("importRemote-\(job.id)")
                if !imported { Button("Télécharger à nouveau si le CBZ a expiré") { if let manga=job.target.manga,let chapter=job.target.chapter { Task { await remote.download(manga,chapter:chapter) } } }.font(p.font(11)) }
            } else {
                Text(job.error?.localizedDescription ?? job.stateLabel).font(p.font(12)).foregroundStyle(p.accent)
                Button("Réessayer") {if let manga=job.target.manga,let chapter=job.target.chapter {Task {await remote.download(manga,chapter:chapter)}}}
            }
        }.frame(maxWidth:.infinity,alignment:.leading).themeCard()
    }
    private func estimate(_ job:RemoteJob)->String {
        guard job.progress.completed >= 3,job.progress.total > job.progress.completed,let date=job.startedAt.flatMap({ISO8601DateFormatter().date(from:$0)}) else {return ""}
        let elapsed=Date().timeIntervalSince(date)
        guard elapsed > 3 else {return ""}
        let seconds=Int(elapsed/Double(job.progress.completed)*Double(job.progress.total-job.progress.completed))
        return " · environ \(seconds < 60 ? "\(seconds) s" : "\(seconds/60) min")"
    }
}
