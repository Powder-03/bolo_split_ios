//
//  AppEnvironment.swift
//  BoloSplit
//
//  Central dependency container wiring Services and ViewModels.
//

import Foundation
import Observation

@Observable
final class AppEnvironment {
    let authService: AuthService
    let apiClient: APIClient
    let ledgerService: LedgerService
    let audioRecorder: AudioRecorderService
    let speechPlayback: SpeechPlaybackService
    let voiceService: VoiceService

    let authViewModel: AuthViewModel
    let friendsViewModel: FriendsTabViewModel
    let groupsViewModel: GroupsTabViewModel
    let selfViewModel: SelfTabViewModel
    let activityViewModel: ActivityTabViewModel

    var presentedVoiceViewModel: VoiceViewModel?

    init() {
        let auth = AuthService()
        let client = APIClient(authProvider: auth)
        let ledger = LedgerService(apiClient: client)
        let recorder = AudioRecorderService()
        let speech = SpeechPlaybackService()
        let voice = VoiceService(apiClient: client)

        self.authService = auth
        self.apiClient = client
        self.ledgerService = ledger
        self.audioRecorder = recorder
        self.speechPlayback = speech
        self.voiceService = voice

        self.authViewModel = AuthViewModel(authService: auth, apiClient: client)
        self.friendsViewModel = FriendsTabViewModel(ledgerService: ledger)
        self.groupsViewModel = GroupsTabViewModel(ledgerService: ledger)
        let activityVM = ActivityTabViewModel(ledgerService: ledger)
        self.activityViewModel = activityVM
        self.selfViewModel = SelfTabViewModel(ledgerService: ledger) {
            await activityVM.loadActivity()
        }
    }

    func makeVoiceViewModel(groupId: UUID? = nil, groupName: String? = nil) -> VoiceViewModel {
        VoiceViewModel(
            recorder: audioRecorder,
            speechService: speechPlayback,
            voiceService: voiceService,
            groupId: groupId,
            groupName: groupName,
            onLedgerMutated: { [weak self] in
                await self?.refreshAllFeeds()
            }
        )
    }

    func openVoiceOverlay(groupId: UUID? = nil, groupName: String? = nil) {
        presentedVoiceViewModel = makeVoiceViewModel(groupId: groupId, groupName: groupName)
    }

    func dismissVoiceOverlay() {
        presentedVoiceViewModel?.cancelAndCleanup()
        presentedVoiceViewModel = nil
    }

    func refreshAllFeeds() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.friendsViewModel.loadData() }
            group.addTask { await self.groupsViewModel.loadGroups() }
            group.addTask { await self.selfViewModel.loadSelfExpenses() }
            group.addTask { await self.activityViewModel.loadActivity() }
        }
    }

    func signOutAndReset() {
        dismissVoiceOverlay()
        authViewModel.signOut()
        friendsViewModel.clear()
        groupsViewModel.clear()
        selfViewModel.clear()
        activityViewModel.clear()
    }
}
