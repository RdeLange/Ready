/*
 PaddleGestureRecognizer.swift -- Recognize Paddle Gestures
 Copyright (C) 2019 Dieter Baron
 
 This file is part of Ready, a home computer emulator for iPad.
 The authors can be contacted at <ready@tpau.group>.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:
 
 1. Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 2. The names of the authors may not be used to endorse or promote
 products derived from this software without specific prior
 written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE AUTHORS ``AS IS'' AND ANY EXPRESS
 OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
 GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
 IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
 IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import UIKit

public class PaddleGestureRecognizer: UIGestureRecognizer {
    @IBInspectable public var paddleHeight: CGFloat = 128

    public var position = 0.5
    public var isbuttonPressed: Bool {
        return !buttonTouches.isEmpty
    }
    
    private var paddleTouch: UITouch?
    private var buttonTouches = Set<UITouch>()
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let view = view else { return }
        
        for touch in touches {
            let location = touch.location(in: view)
            
            if location.y > view.bounds.height - paddleHeight && paddleTouch == nil {
                paddleTouch = touch
                updatePaddle()
            }
            else {
                buttonTouches.insert(touch)
            }
        }
        
        updateState()
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            if touch == paddleTouch {
                paddleTouch = nil
            }
            else {
                buttonTouches.remove(touch)
            }
        }
        updateState()
    }
    
    override public func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        touchesEnded(touches, with: event)
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        for touch in touches {
            if touch == paddleTouch {
                updatePaddle()
                updateState()
            }
        }
    }
    
    private func updateState() {
        if paddleTouch != nil || !buttonTouches.isEmpty {
            if state == .possible {
                state = .began
            }
            else {
                state = .changed
            }
        }
        else {
            state = .ended
        }
    }
    
    private func updatePaddle() {
        guard let touch = paddleTouch, let view = view else { return }
        
        position = Double(touch.location(in: view).x / view.bounds.width)
    }
}
