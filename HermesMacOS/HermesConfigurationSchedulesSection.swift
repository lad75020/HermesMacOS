//
//  HermesConfigurationSchedulesSection.swift
//  HermesMacOS
//

import SwiftUI

extension HermesConfigurationView {
        var filteredDashboardSchedules: [HermesDashboardScheduleJob] {
            let query = scheduleQuery.trimmedForHermes
            guard !query.isEmpty else { return dashboardSchedules.jobs }
            return dashboardSchedules.jobs.filter { job in
                job.displayName.localizedCaseInsensitiveContains(query) ||
                job.scheduleLabel.localizedCaseInsensitiveContains(query) ||
                job.statusLabel.localizedCaseInsensitiveContains(query) ||
                job.profileLabel.localizedCaseInsensitiveContains(query) ||
                job.skillLabel.localizedCaseInsensitiveContains(query) ||
                job.deliveryLabel.localizedCaseInsensitiveContains(query) ||
                job.chainLabel.localizedCaseInsensitiveContains(query) ||
                job.contentPreview.localizedCaseInsensitiveContains(query)
            }
        }


        var selectedScheduleDeliveryValue: String {
            if scheduleDeliveryTarget == "custom" { return scheduleCustomDeliveryTarget.trimmedForHermes }
            return scheduleDeliveryTarget
        }


        var selectedScheduleChainJobs: [String] {
            scheduleChainSourceJobID.trimmedForHermes.isEmpty ? [] : [scheduleChainSourceJobID.trimmedForHermes]
        }


        var canCreateSchedule: Bool {
            !scheduleName.trimmedForHermes.isEmpty &&
            !scheduleExpression.trimmedForHermes.isEmpty &&
            !selectedScheduleDeliveryValue.isEmpty &&
            (!schedulePrompt.trimmedForHermes.isEmpty || !scheduleSkillName.trimmedForHermes.isEmpty) &&
            (scheduleJobKind == "prompt" || !scheduleSkillName.trimmedForHermes.isEmpty) &&
            !dashboardSchedules.isLoading
        }


        var scheduleStudioOutput: String {
            let messages = [dashboardSchedules.lastActionMessage, dashboardSchedules.lastErrorMessage].filter { !$0.isEmpty }
            return messages.isEmpty ? "Automation Studio ready. Create prompt jobs, skill-backed jobs, chained jobs, or queue existing jobs to run now." : messages.joined(separator: "\n")
        }


        var schedulePreviewText: String {
            let chainName = dashboardSchedules.jobs.first(where: { $0.id == scheduleChainSourceJobID })?.displayName ?? scheduleChainSourceJobID
            var lines = [
                "Name: \(scheduleName.trimmedForHermes.isEmpty ? "Untitled schedule" : scheduleName.trimmedForHermes)",
                "Type: \(scheduleJobKind == "skill" ? "Skill-backed" : "Prompt-based")",
                "Schedule: \(scheduleExpression.trimmedForHermes.isEmpty ? "—" : scheduleExpression.trimmedForHermes)",
                "Delivery: \(selectedScheduleDeliveryValue.isEmpty ? "—" : selectedScheduleDeliveryValue)"
            ]
            if !scheduleSkillName.trimmedForHermes.isEmpty { lines.append("Skills: \(scheduleSkillName.trimmedForHermes)") }
            if !scheduleChainSourceJobID.trimmedForHermes.isEmpty { lines.append("Context from: \(chainName)") }
            lines.append("Prompt preview:\n\(schedulePrompt.trimmedForHermes.isEmpty ? "—" : schedulePrompt.trimmedForHermes)")
            return lines.joined(separator: "\n")
        }


        var dashboardSchedulesSection: some View {
            runtimeSection(
                title: "Schedules",
                subtitle: "Cron / Automation Studio: create prompt or skill-backed jobs, choose delivery, chain outputs, preview, and operate runs.",
                systemImage: "calendar.badge.clock",
                isExpanded: $isSchedulesExpanded,
                output: scheduleStudioOutput
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        TextField("Search schedules, skills, delivery, output, or profile", text: $scheduleQuery)
                        Button {
                            dashboardSchedules.refresh(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .disabled(dashboardSchedules.isLoading)
                    }

                    scheduleAutomationStudio

                    if dashboardSchedules.isLoading && dashboardSchedules.jobs.isEmpty {
                        ProgressView("Loading schedules from Hermes Dashboard…")
                            .controlSize(.small)
                    } else if !dashboardSchedules.lastErrorMessage.isEmpty {
                        Text(dashboardSchedules.lastErrorMessage)
                            .font(.caption)
                            .foregroundStyle(Color.orange)
                    } else if filteredDashboardSchedules.isEmpty {
                        Text(dashboardSchedules.jobs.isEmpty ? "No schedules reported by the Hermes Dashboard." : "No matching schedules.")
                            .font(.caption)
                            .foregroundStyle(Color.hermesSecondaryText)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(filteredDashboardSchedules) { job in
                                dashboardScheduleRow(job)
                            }
                        }
                    }
                }
            }
        }


        var scheduleAutomationStudio: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Picker("Template", selection: $selectedScheduleTemplateID) {
                        Text("Custom").tag("")
                        ForEach(HermesScheduleAutomationTemplate.defaults) { template in
                            Text(template.title).tag(template.id)
                        }
                    }
                    .frame(maxWidth: 280)
                    Button {
                        applySelectedScheduleTemplate()
                    } label: {
                        Label("Apply template", systemImage: "wand.and.stars")
                    }
                    .disabled(selectedScheduleTemplateID.isEmpty)
                    Spacer()
                    Picker("Job type", selection: $scheduleJobKind) {
                        Text("Prompt job").tag("prompt")
                        Text("Skill-backed").tag("skill")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }

                HStack(spacing: 10) {
                    TextField("Name", text: $scheduleName)
                    TextField("Schedule, e.g. every 2h or 0 9 * * *", text: $scheduleExpression)
                }

                TextField(scheduleJobKind == "skill" ? "Task instruction for the selected skill" : "Self-contained prompt", text: $schedulePrompt, axis: .vertical)
                    .lineLimit(3...7)

                HStack(spacing: 10) {
                    skillSelector
                    Picker("Deliver", selection: $scheduleDeliveryTarget) {
                        ForEach(HermesScheduleDeliveryTarget.defaults) { target in
                            Text(target.title).tag(target.id)
                        }
                    }
                    .frame(width: 190)
                    if scheduleDeliveryTarget == "custom" {
                        TextField("platform:chat_id:thread_id or local", text: $scheduleCustomDeliveryTarget)
                            .frame(minWidth: 220)
                    }
                }

                HStack(spacing: 10) {
                    Picker("Use output from", selection: $scheduleChainSourceJobID) {
                        Text("No upstream job").tag("")
                        ForEach(dashboardSchedules.jobs) { job in
                            Text("\(job.displayName) (\(job.id))").tag(job.id)
                        }
                    }
                    .frame(maxWidth: 420)
                    Button {
                        addSchedule()
                    } label: {
                        Label("Create automation", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canCreateSchedule)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("Test run preview", systemImage: "doc.text.magnifyingglass")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.hermesSecondaryText)
                    Text(schedulePreviewText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Color.hermesSecondaryText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }


        var skillSelector: some View {
            HStack(spacing: 8) {
                TextField(scheduleJobKind == "skill" ? "Required skill name" : "Optional skill name", text: $scheduleSkillName)
                Menu {
                    ForEach(dashboardSkills.skills.filter { $0.isEnabled }) { skill in
                        Button(skill.name) { scheduleSkillName = skill.name }
                    }
                } label: {
                    Label("Pick skill", systemImage: "square.stack.3d.up")
                        .labelStyle(.titleAndIcon)
                }
                .disabled(dashboardSkills.skills.isEmpty)
            }
        }


        func applySelectedScheduleTemplate() {
            guard let template = HermesScheduleAutomationTemplate.defaults.first(where: { $0.id == selectedScheduleTemplateID }) else { return }
            scheduleName = template.title
            scheduleExpression = template.schedule
            schedulePrompt = template.prompt
            scheduleSkillName = template.skillName
            scheduleJobKind = template.skillName.isEmpty ? "prompt" : "skill"
            scheduleDeliveryTarget = template.delivery
            scheduleCustomDeliveryTarget = ""
        }


        func jobDisplayName(for id: String) -> String {
            dashboardSchedules.jobs.first(where: { $0.id == id })?.displayName ?? id
        }


        func addSchedule() {
            dashboardSchedules.createSchedule(
                name: scheduleName,
                schedule: scheduleExpression,
                prompt: schedulePrompt,
                skillName: scheduleSkillName,
                delivery: selectedScheduleDeliveryValue,
                contextFrom: selectedScheduleChainJobs,
                dashboardBaseURL: dashboardURL,
                apiSettings: apiSettings
            )
            scheduleName = ""
            scheduleExpression = ""
            schedulePrompt = ""
            scheduleSkillName = ""
            scheduleChainSourceJobID = ""
        }


        func dashboardScheduleRow(_ job: HermesDashboardScheduleJob) -> some View {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(job.displayName)
                                .font(.headline)
                            Text(job.statusLabel)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background((job.isEnabled ? Color.green : Color.gray).opacity(0.16), in: Capsule())
                                .foregroundStyle(job.isEnabled ? Color.green : Color.hermesSecondaryText)
                            Text(job.profileLabel)
                                .font(.caption.monospaced())
                                .foregroundStyle(Color.hermesSecondaryText)
                            Text(job.deliveryLabel)
                                .font(.caption.monospaced())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.hermesActionBlue.opacity(0.12), in: Capsule())
                                .foregroundStyle(Color.hermesActionBlue)
                        }
                        Text(job.scheduleLabel)
                            .font(.caption.monospaced())
                            .foregroundStyle(Color.hermesSecondaryText)
                        if !job.skillLabel.isEmpty {
                            Text("Skill: \(job.skillLabel)")
                                .font(.caption)
                                .foregroundStyle(Color.hermesActionBlue)
                        }
                        if !job.chainLabel.isEmpty {
                            Text("Uses output from: \(job.chainLabel.split(separator: ",").map { jobDisplayName(for: String($0).trimmedForHermes) }.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(Color.hermesSecondaryText)
                        }
                        Text(job.contentPreview)
                            .font(.caption)
                            .foregroundStyle(Color.hermesSecondaryText)
                            .lineLimit(3)
                        HStack(spacing: 12) {
                            Text("Next: \(job.nextRunAt ?? "—")")
                            Text("Last: \(job.lastRunAt ?? "—")")
                            Text("Status: \(job.lastStatusLabel)")
                        }
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Color.hermesSecondaryText.opacity(0.85))
                        if !job.failureLabel.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Last failure")
                                    .font(.caption2.weight(.semibold))
                                Text(job.failureLabel)
                                    .font(.caption)
                                    .lineLimit(3)
                            }
                            .foregroundStyle(Color.orange)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        Button {
                            dashboardSchedules.runJobNow(job, dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                        } label: {
                            Label("Run now", systemImage: "play.circle")
                        }
                        .disabled(dashboardSchedules.isLoading)

                        Button {
                            dashboardSchedules.setJobEnabled(job, enabled: !job.isEnabled, dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                        } label: {
                            Label(job.isEnabled ? "Pause" : "Resume", systemImage: job.isEnabled ? "pause.circle" : "arrow.clockwise.circle")
                        }
                        .disabled(dashboardSchedules.isLoading)

                        Button {
                            dashboardSchedules.loadLastOutput(for: job, hermesHome: runtime.hermesHome)
                        } label: {
                            Label("Output", systemImage: "doc.text")
                        }
                    }
                    .buttonStyle(.bordered)
                }

                if let output = dashboardSchedules.lastOutputByJobID[job.id], !output.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Run output")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.hermesSecondaryText)
                        ScrollView {
                            Text(output)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.hermesSecondaryText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                        .frame(minHeight: 80, maxHeight: 220)
                        .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        }


}

struct HermesScheduleAutomationTemplate: Identifiable {
    let id: String
    let title: String
    let schedule: String
    let prompt: String
    let skillName: String
    let delivery: String

    static let defaults: [HermesScheduleAutomationTemplate] = [
        HermesScheduleAutomationTemplate(
            id: "daily-briefing",
            title: "Daily briefing",
            schedule: "0 8 * * *",
            prompt: "Create a concise daily briefing for Laurent. Include the most important calendar/context reminders, noteworthy AI or developer news, and actionable next steps. Keep it short and cite sources when web results are used.",
            skillName: "",
            delivery: "local"
        ),
        HermesScheduleAutomationTemplate(
            id: "repo-check",
            title: "Repo check",
            schedule: "0 9 * * 1-5",
            prompt: "Inspect the configured repository. Summarize git status, recent changes, failing checks, and any risky TODOs. Do not modify files; report only.",
            skillName: "codebase-inspection",
            delivery: "local"
        ),
        HermesScheduleAutomationTemplate(
            id: "blog-watcher",
            title: "Blog watcher",
            schedule: "every 6h",
            prompt: "Scan the configured blogs or RSS feeds and report only genuinely new or important items. Start with [SILENT] if there is nothing worth sharing.",
            skillName: "blogwatcher",
            delivery: "local"
        ),
        HermesScheduleAutomationTemplate(
            id: "session-cleanup",
            title: "Session cleanup",
            schedule: "0 3 * * 0",
            prompt: "Review Hermes session storage for stale, empty, or failed sessions that are safe to clean up. Summarize candidates and actions taken; avoid deleting active sessions.",
            skillName: "",
            delivery: "local"
        ),
        HermesScheduleAutomationTemplate(
            id: "model-eval",
            title: "Model eval",
            schedule: "0 6 * * 0",
            prompt: "Run or prepare the configured lightweight model evaluation, then summarize score deltas, failures, and recommended follow-up. Keep raw logs out of the delivery unless needed.",
            skillName: "evaluating-llms-harness",
            delivery: "local"
        ),
        HermesScheduleAutomationTemplate(
            id: "backup",
            title: "Backup",
            schedule: "0 2 * * *",
            prompt: "Create or verify the configured Hermes backup. Report backup path, size, retention status, and any failure that needs attention.",
            skillName: "",
            delivery: "local"
        )
    ]
}

struct HermesScheduleDeliveryTarget: Identifiable {
    let id: String
    let title: String

    static let defaults: [HermesScheduleDeliveryTarget] = [
        HermesScheduleDeliveryTarget(id: "local", title: "Local only"),
        HermesScheduleDeliveryTarget(id: "origin", title: "Origin chat"),
        HermesScheduleDeliveryTarget(id: "all", title: "All home channels"),
        HermesScheduleDeliveryTarget(id: "telegram", title: "Telegram"),
        HermesScheduleDeliveryTarget(id: "discord", title: "Discord"),
        HermesScheduleDeliveryTarget(id: "slack", title: "Slack"),
        HermesScheduleDeliveryTarget(id: "email", title: "Email"),
        HermesScheduleDeliveryTarget(id: "custom", title: "Custom…")
    ]
}
