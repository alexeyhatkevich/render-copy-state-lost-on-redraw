import Testing
import RenderCopyState

/// Builds a consent page, shows it once and flips "I agree" ON like a user would.
private func presentedPageAccepted(_ toggle: RCToggle.Type, boundKey: String? = nil) -> RCConsentPage {
    let page = RCConsentPage(toggleClass: toggle, boundKey: boundKey)
    page.present()
    page.renderedToggle.userDidToggle(true)
    return page
}

@Suite("Render copies")
struct RenderCopyTests {
    // Proves the live element is a copy whose parent is the source container.
    @Test func test_rendered_element_is_a_copy_pointing_at_the_source_parent() {
        let page = RCConsentPage(toggleClass: RCNaiveToggle.self)
        page.present()
        #expect(page.renderedToggle !== page.sourceToggle)
        #expect(page.renderedToggle.parent === page)
    }

    // Proves a sibling visibility change rebuilds every render copy.
    @Test func test_sibling_visibility_change_rebuilds_the_copies() {
        let page = RCConsentPage(toggleClass: RCNaiveToggle.self)
        page.present()
        let before = page.renderedToggle
        page.setHintHidden(true)
        #expect(page.renderedToggle !== before)
        #expect(page.redrawCount == 2)
    }
}

@Suite("Naive: state lives on the render copy")
struct NaiveTests {
    // Proves the bug: the switch snaps back to OFF after an unrelated redraw.
    @Test func test_naive_user_toggle_is_lost_on_redraw() {
        let page = presentedPageAccepted(RCNaiveToggle.self)
        #expect(page.renderedToggle.isSelected)
        page.setHintHidden(true)
        #expect(page.renderedToggle.isSelected == false)
    }

    // Proves the desync QA saw: switch shows OFF but Next is still enabled.
    @Test func test_naive_ui_and_logic_desync_after_redraw() {
        let page = presentedPageAccepted(RCNaiveToggle.self)
        page.setHintHidden(true)
        #expect(page.renderedToggle.isSelected == false)
        #expect(page.nextEnabled == true)
    }

    // Proves the programmatic "set selected" path loses its value the same way.
    @Test func test_naive_programmatic_set_is_lost_on_redraw() {
        let page = RCConsentPage(toggleClass: RCNaiveToggle.self)
        page.present()
        page.renderedToggle.applySelected(true)
        page.setHintHidden(true)
        #expect(page.renderedToggle.isSelected == false)
    }
}

@Suite("Write-through only")
struct WriteThroughTests {
    // Proves fix part 1: the value reaches the source and survives redraws.
    @Test func test_writeThrough_user_toggle_survives_redraw() {
        let page = presentedPageAccepted(RCWriteThroughToggle.self)
        page.setHintHidden(true)
        page.setHintHidden(false)
        #expect(page.sourceToggle.isSelected)
        #expect(page.renderedToggle.isSelected)
        #expect(page.nextEnabled == page.renderedToggle.isSelected)
    }

    // Proves the second entry point (programmatic set) is written through too.
    @Test func test_writeThrough_programmatic_set_survives_redraw() {
        let page = RCConsentPage(toggleClass: RCWriteThroughToggle.self)
        page.present()
        page.renderedToggle.applySelected(true)
        page.setHintHidden(true)
        #expect(page.renderedToggle.isSelected)
    }

    // Proves the regression found in review: with a cached page the tap leaks into the next visit.
    @Test func test_writeThrough_without_reset_leaks_into_next_visit() {
        let cache = RCPageCache()
        let first = cache.page(named: "consent") { RCConsentPage(toggleClass: RCWriteThroughToggle.self) }
        first.present()
        first.renderedToggle.userDidToggle(true)

        // User leaves and comes back later: same cached model, fresh presentation.
        let second = cache.page(named: "consent") { RCConsentPage(toggleClass: RCWriteThroughToggle.self) }
        #expect(second === first)
        second.present()
        #expect(second.renderedToggle.isSelected)   // already "accepted" - nobody tapped it
        #expect(second.nextEnabled)
    }

    // Proves bound toggles skip write-through: the store owns the value and still survives redraws.
    @Test func test_writeThrough_bound_toggle_keeps_value_in_store_not_source() {
        let page = presentedPageAccepted(RCWriteThroughToggle.self, boundKey: "consentAccepted")
        page.setHintHidden(true)
        #expect(page.sourceToggle.isSelected == false)
        #expect(page.dataStore["consentAccepted"] as? Bool == true)
        #expect(page.renderedToggle.isSelected)
    }
}

@Suite("Fixed: write-through + reset on fresh presentation")
struct FixedTests {
    // Proves the full fix keeps the value across any number of redraws.
    @Test func test_fixed_user_toggle_survives_redraws() {
        let page = presentedPageAccepted(RCFixedToggle.self)
        for hidden in [true, false, true] { page.setHintHidden(hidden) }
        #expect(page.renderedToggle.isSelected)
        #expect(page.nextEnabled)
    }

    // Proves the programmatic path also survives redraws with the full fix.
    @Test func test_fixed_programmatic_set_survives_redraw() {
        let page = RCConsentPage(toggleClass: RCFixedToggle.self)
        page.present()
        page.renderedToggle.applySelected(true)
        page.setHintHidden(true)
        #expect(page.renderedToggle.isSelected)
    }

    // Proves a revisit of the cached page starts from the authored value again.
    @Test func test_fixed_revisit_resets_to_authored_value() {
        let cache = RCPageCache()
        let build = { RCConsentPage(toggleClass: RCFixedToggle.self) }
        let first = cache.page(named: "consent", build: build)
        first.present()
        first.renderedToggle.userDidToggle(true)

        let second = cache.page(named: "consent", build: build)
        second.present()
        #expect(second === first)
        #expect(second.renderedToggle.isSelected == false)
        #expect(second.nextEnabled == false)
        #expect(second.presentationCount == 2)
    }

    // Proves authoredSelected travels through copyWithZone:, so a copy can reset too.
    @Test func test_fixed_copy_remembers_authored_value() throws {
        let original = RCFixedToggle(identifier: "agree", selected: true)
        original.applySelected(false)
        let copy = try #require(original.copy() as? RCFixedToggle)
        #expect(copy.authoredSelected == true)
        copy.prepareForFreshPresentation()
        #expect(copy.isSelected == true)
    }
}
